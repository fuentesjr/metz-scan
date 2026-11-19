# frozen_string_literal: true

require "json"
require "psych"
require "rubocop"
require "stringio"

require "metz/file_classifier"
require "metz_scan/commands/scan/execution_config_store"
require "metz_scan/commands/scan/project_config_scope"
require "metz_scan/commands/scan/rubocop_failure"
require "metz_scan/commands/scan/rubocop_invocation"
require "metz_scan/commands/scan/suppression_ledger"
require "metz_scan/commands/scan/target_ruby_version"

module MetzScan
  module Commands
    class Scan
      module Runner
        FORMATTER = "RuboCop::Formatter::MetzJsonFormatter"

        class Error < StandardError; end

        Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

        def self.invoke(paths, all_cops: false, stderr: $stderr, **scope)
          with_errors { perform(paths, all_cops: all_cops, stderr: stderr, scope: scope) }
        end

        def self.perform(paths, all_cops:, stderr:, scope: {})
          store = scope[:store] || (ProjectConfigScope.store unless all_cops)
          exec_store = ExecutionConfigStore.new(store) unless all_cops
          files = inspection_paths(paths, all_cops: all_cops, store: store, target_files: scope[:target_files])
          report = files.empty? ? empty_report : scan(files, all_cops: all_cops, store: store)
          report.tap { ProjectConfigScope.warn_scope_notes(files, stderr, exec_store: exec_store) unless all_cops }
        end

        def self.scan(paths, all_cops:, store: nil)
          report = TargetRubyVersion.with_project_config(paths, all_cops: all_cops, store: store) do
            parse_output(RuboCopInvocation.scan(paths, all_cops: all_cops, store: store))
          end
          return report if all_cops

          SuppressionLedger.with_store(store) { SuppressionLedger.apply(report) }
        end

        # Only what RuboCop and config loading raise; a metz-scan bug keeps its class and backtrace.
        def self.with_errors
          yield
        rescue LoadError, RuboCop::Error, Psych::Exception, SystemCallError => e
          raise Error, concise_message(e.message)
        end

        def self.require_metz_plugin
          require "rubocop-metz"
        rescue LoadError => e
          raise Error, "could not load rubocop-metz: #{e.message}"
        end

        def self.inspection_paths(paths, all_cops:, store: nil, target_files: nil)
          return paths if all_cops

          (target_files || TargetFileDiscovery.discover(paths, store: store)).map { |path| display_path(path) }
        end

        def self.with_redirected_io(out, err)
          original = redirect_to(out, err)
          yield
        ensure
          restore_io(original) if original
        end

        def self.redirect_to(out, err)
          previous = [$stdout, $stderr]
          $stdout = out
          $stderr = err
          previous
        end

        def self.restore_io(previous)
          $stdout = previous[0]
          $stderr = previous[1]
        end

        def self.parse_output(result)
          raise Error, RubocopFailure.message(result) if RubocopFailure.failed?(result)

          JSON.parse(result.stdout)
        rescue JSON::ParserError
          raise Error, RubocopFailure.message(result)
        end

        def self.concise_message(text)
          text.to_s.lines.map(&:strip)
              .reject(&:empty?)
              .reject { |line| stack_trace_line?(line) }
              .first(3)
              .join(" ")
        end

        def self.stack_trace_line?(line)
          line == "Traceback (most recent call last):" || line.match?(/:\d+:in [`']/)
        end

        def self.exit_code_for(parsed)
          Array(parsed["files"]).any? { |f| Array(f["offenses"]).any? } ? 1 : 0
        end

        def self.empty_report
          { "metadata" => metadata, "files" => [], "suppressions" => [],
            "summary" => { "offense_count" => 0, "target_file_count" => 0, "inspected_file_count" => 0 } }
        end

        def self.metadata
          { "rubocop_version" => RuboCop::Version::STRING, "ruby_engine" => RUBY_ENGINE,
            "ruby_version" => RUBY_VERSION, "ruby_patchlevel" => RUBY_PATCHLEVEL.to_s,
            "ruby_platform" => RUBY_PLATFORM }
        end

        def self.display_path(path)
          expanded_path = File.expand_path(path)
          cwd = "#{File.expand_path(Dir.pwd)}#{File::SEPARATOR}"
          return expanded_path.delete_prefix(cwd) if expanded_path.start_with?(cwd)

          expanded_path
        end
      end

      module TargetFileDiscovery
        STORE_KEY = :metz_scan_target_file_discovery_store

        module_function

        def scan_scope(paths)
          store = ProjectConfigScope.store
          { store: store, target_files: Runner.with_errors { discover(paths, store: store) } }
        end

        def analyzer_scope(options)
          if options[:all_cops]
            return { rubocop_store: options[:rubocop_store] || Runner.with_errors { all_cops_store } }
          end

          { store: options[:store] || ProjectConfigScope.store }
        end

        def for_analyzer(paths, all_cops: false, store: nil, rubocop_store: nil)
          return for_all_cops(paths, rubocop_store: rubocop_store || all_cops_store) if all_cops

          discover(paths, store: store)
        end

        def discover(paths, store: nil)
          Runner.require_metz_plugin
          ProjectConfigScope.reset_unresolved_inherit_gems!
          with_store(store || ProjectConfigScope.store) { for_project_config(paths) }
        end

        def for_project_config(paths, store: active_store)
          finder = RuboCop::TargetFinder.new(store, {})
          files = (finder.find(paths, :all_file_types) + view_templates(paths, finder, store)).uniq
          load_governing_configs(files, store)
        end

        def for_all_cops(paths, rubocop_store: all_cops_store)
          ProjectConfigScope.ensure_metz_defaults_loaded
          RuboCop::TargetFinder.new(rubocop_store, {}).find(paths, :all_file_types)
        end

        def all_cops_store
          ProjectConfigScope.ensure_metz_defaults_loaded
          RuboCop::ConfigStore.new
        end

        def with_store(store)
          previous = Thread.current[STORE_KEY]
          Thread.current[STORE_KEY] = store
          yield
        ensure
          Thread.current[STORE_KEY] = previous
        end

        def active_store
          Thread.current[STORE_KEY] || ProjectConfigScope.store
        end

        # RuboCop's directory discovery finds only Ruby files; the Metz view cop also
        # checks template files in its effective Include scope. Hidden directories and
        # the project's AllCops: Exclude apply as they do to Ruby.
        def view_templates(paths, finder, store)
          exec_store = ExecutionConfigStore.new(store)
          cops = {}.compare_by_identity
          paths.select { |path| File.directory?(path) }.flat_map do |dir|
            templates_in_dir(File.expand_path(dir), finder, exec_store, cops)
          end
        end

        def templates_in_dir(base_dir, finder, exec_store, cops)
          finder.find_files(base_dir, 0).select { |file| included_template?(file, exec_store, cops) }
        end

        def included_template?(file, exec_store, cops)
          return false unless Metz::FileClassifier.template?(file)

          exec_config = exec_store.for_file(file)
          views_cop = cops[exec_config] ||= RuboCop::Cop::Metz::ViewsDeepNavigation.new(exec_config)
          !exec_config.file_to_exclude?(file) && views_cop.relevant_file?(file)
        end

        # ExecutionConfigStore builds execution configs per unique loaded_path only, so
        # loading every file's governing config here makes a broken nested config fail the scan.
        def load_governing_configs(files, store)
          files.each { |file| store.for_file(file) }
        end
      end
    end
  end
end
