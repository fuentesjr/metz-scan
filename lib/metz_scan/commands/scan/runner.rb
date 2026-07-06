# frozen_string_literal: true

require "json"
require "psych"
require "rubocop"
require "stringio"

module MetzScan
  module Commands
    class Scan
      module Runner
        FORMATTER = "RuboCop::Formatter::MetzJsonFormatter"

        class Error < StandardError; end

        Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

        def self.invoke(paths, all_cops: false)
          with_errors do
            paths = inspection_paths(paths, all_cops: all_cops)
            return empty_report if paths.empty?

            parse_output(capture_output(rubocop_argv(paths, all_cops: all_cops)))
          end
        end

        def self.with_errors
          yield
        rescue LoadError => e
          raise_load_error(e)
        rescue StandardError => e
          raise Error, concise_message(e.message)
        end

        def self.raise_load_error(err)
          raise Error, "could not load rubocop-metz: #{err.message}"
        end

        def self.rubocop_argv(paths, all_cops:)
          require "rubocop-metz"
          ["--plugin", "rubocop-metz", *cop_selection_argv(all_cops), "--format", FORMATTER, *paths]
        end

        def self.inspection_paths(paths, all_cops:)
          return paths if all_cops

          target_files_for_project_config(paths).map { |path| display_path(path) }
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
          line == "Traceback (most recent call last):" || line.match?(/\.rb:\d+:in /)
        end

        def self.exit_code_for(parsed)
          offenses?(parsed) ? 1 : 0
        end

        def self.offenses?(parsed)
          Array(parsed["files"]).any? { |f| Array(f["offenses"]).any? }
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

        def self.target_files_for_project_config(paths)
          TargetFileDiscovery.for_project_config(paths)
        end
      end

      module TargetFileDiscovery
        module_function

        def for_project_config(paths)
          find(paths, RuboCop::ConfigStore.new)
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
