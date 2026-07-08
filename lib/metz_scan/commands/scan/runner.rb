# frozen_string_literal: true

require "json"
require "psych"
require "rubocop"
require "stringio"

require "metz_scan/commands/scan/project_config_scope"
require "metz_scan/commands/scan/target_ruby_version"

module MetzScan
  module Commands
    class Scan
      module Runner
        FORMATTER = "RuboCop::Formatter::MetzJsonFormatter"

        class Error < StandardError; end

        Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

        def self.invoke(paths, all_cops: false, stderr: $stderr)
          with_errors { perform(paths, all_cops: all_cops, stderr: stderr) }
        end

        def self.perform(paths, all_cops:, stderr:)
          ProjectConfigScope.reset_unresolved_inherit_gems! unless all_cops
          paths = inspection_paths(paths, all_cops: all_cops)
          report = paths.empty? ? empty_report : scan(paths, all_cops: all_cops)
          report.tap { ProjectConfigScope.warn_unresolved_inherit_gems(stderr) unless all_cops }
        end

        def self.scan(paths, all_cops:)
          report = TargetRubyVersion.with_project_config(paths, all_cops: all_cops) do
            parse_output(capture_output(rubocop_argv(paths, all_cops: all_cops)))
          end
          all_cops ? report : ProjectCopScope.honor(report)
        end

        def self.with_errors
          yield
        rescue LoadError, StandardError => e
          raise Error, concise_message(e.message)
        end

        def self.rubocop_argv(paths, all_cops:)
          require_metz_plugin
          ["--plugin", "rubocop-metz", *cop_selection_argv(all_cops), "--format", FORMATTER, *paths]
        end

        def self.require_metz_plugin
          require "rubocop-metz"
        rescue LoadError => e
          raise Error, "could not load rubocop-metz: #{e.message}"
        end

        def self.inspection_paths(paths, all_cops:)
          return paths if all_cops

          TargetFileDiscovery.for_project_config(paths).map { |path| display_path(path) }
        end

        def self.cop_selection_argv(all_cops)
          all_cops ? [] : ["--force-default-config", "--enable-all-cops", "--only", "Metz"]
        end

        def self.capture_output(argv)
          out = StringIO.new
          err = StringIO.new
          status = with_redirected_io(out, err) { RuboCop::CLI.new.run(argv) }
          Result.new(stdout: out.string, stderr: err.string, status: status)
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
          JSON.parse(result.stdout)
        rescue JSON::ParserError
          raise Error, failure_message(result)
        end

        def self.failure_message(result)
          detail = concise_message(result.stderr)
          detail = concise_message(result.stdout) if detail.empty?
          return detail unless detail.empty?

          "RuboCop exited with status #{result.status} without JSON output"
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
          { "metadata" => metadata, "files" => [],
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

      # Default mode forces stock Metz *tuning* (--force-default-config) but must
      # still honor the project's per-cop file *scope* (Include/Exclude), the
      # same way #33 honors AllCops: Exclude. RuboCop's own excluded_file?
      # resolves the project config's scope per cop; offenses on files a cop is
      # scoped off are dropped here. Invalid project config -> nothing to honor
      # (matches the forced-default target-discovery fallback). See #37.
      module ProjectCopScope
        module_function

        def honor(report)
          store = ProjectConfigScope.store
          files = Array(report["files"]).map { |file| reject_scoped_off(store, file) }
          recount(report.merge("files" => files))
        rescue RuboCop::Error, Psych::Exception
          report
        end

        def reject_scoped_off(store, file)
          absolute = File.expand_path(file.fetch("path"))
          kept = Array(file["offenses"]).reject { |o| scoped_off?(store, o.fetch("cop_name"), absolute) }
          file.merge("offenses" => kept)
        end

        def scoped_off?(store, cop_name, absolute_path)
          cop_class = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
          return false unless cop_class

          cop_class.new(store.for_file(absolute_path)).excluded_file?(absolute_path)
        end

        def recount(report)
          return report unless report["summary"]

          count = Array(report["files"]).sum { |file| Array(file["offenses"]).size }
          report.merge("summary" => report["summary"].merge("offense_count" => count))
        end
      end

      module TargetFileDiscovery
        module_function

        def for_project_config(paths)
          find(paths, ProjectConfigScope.store)
        rescue RuboCop::Error, Psych::Exception
          with_forced_defaults(paths)
        end

        def with_forced_defaults(paths)
          find(paths, RuboCop::ConfigStore.new.tap(&:force_default_config!))
        end

        def find(paths, store)
          RuboCop::TargetFinder.new(store, {}).find(paths, :all_file_types)
        end
      end
    end
  end
end
