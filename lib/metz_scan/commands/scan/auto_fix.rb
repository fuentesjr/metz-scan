# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"

require "metz_scan/commands/scan/ignored_cli_options_note"
require "metz_scan/commands/scan/rubocop_invocation"

module MetzScan
  module Commands
    class Scan
      class AutoFix
        def initialize(stdout:, stderr:)
          @stdout = stdout
          @stderr = stderr
        end

        def run(options)
          Runner.with_errors { Runner.require_metz_plugin }
          scope = resolve_scope(options)
          status = options.dry_run ? run_dry(options, scope) : run_in_place(options, scope)
          IgnoredCliOptionsNote.print_note(stderr)
          status
        end

        private

        attr_reader :stdout, :stderr

        def resolve_scope(options)
          scope = options.all_cops ? {} : TargetFileDiscovery.scan_scope(options.paths)
          paths = Runner.with_errors { Runner.inspection_paths(options.paths, all_cops: options.all_cops, **scope) }
          raise CheckFailure::NoFilesScanned, options.paths if !options.all_cops && paths.empty?

          { paths: paths, store: scope[:store] }
        end

        def run_in_place(options, scope)
          result = checked_rubocop(options, scope)
          stdout.write(result.stdout)
          stderr.write(result.stderr)
          result.status
        end

        def run_dry(options, scope)
          snapshot = capture_files(scope[:paths])
          dry_run_result(snapshot, checked_rubocop(options, scope))
        ensure
          restore_files(snapshot)
        end

        def dry_run_result(snapshot, result)
          print_diffs(snapshot)
          print_rubocop_failure(result) unless result.status.zero?
          result.status
        end

        # Fails like a plain scan, before any output: RuboCop exits 1 for a cop error and for
        # remaining offenses alike, and only its own report says how many files it inspected.
        def checked_rubocop(options, scope)
          Tempfile.create(["metz-auto-fix-", ".json"]) do |report|
            run_rubocop(options, scope, report.path).tap { |result| check!(result, report, options) }
          end
        end

        def run_rubocop(options, scope, report_path)
          Runner.with_errors do
            TargetRubyVersion.with_project_config(scope[:paths], all_cops: options.all_cops, store: scope[:store]) do
              invoke_rubocop(options, scope, report_path)
            end
          end
        end

        def invoke_rubocop(options, scope, report_path)
          RuboCopInvocation.auto_fix(scope[:paths], options: options, report_path: report_path, store: scope[:store])
        end

        def check!(result, report, options)
          raise Runner::Error, RubocopFailure.message(result) if RubocopFailure.failed?(result)
          raise CheckFailure::NoFilesScanned, options.paths if inspected_file_count(result, report.path).zero?
        end

        def inspected_file_count(result, report_path)
          JSON.parse(File.read(report_path)).dig("summary", "inspected_file_count")
        rescue JSON::ParserError
          raise Runner::Error, RubocopFailure.message(result)
        end

        def capture_files(paths) = files_under(paths).to_h { |path| [path, File.binread(path)] }

        def files_under(paths) = paths.flat_map { |path| File.directory?(path) ? regular_files_in(path) : [path] }

        def regular_files_in(dir) = Dir.glob(File.join(dir, "**/*")).select { |entry| File.file?(entry) }

        def print_diffs(snapshot) = snapshot.each { |path, original| print_file_diff(path, original) }

        def print_rubocop_failure(result)
          stderr.print(result.stderr) unless result.stderr.empty?
          stderr.print(result.stdout) unless result.stdout.empty?
        end

        def print_file_diff(path, original)
          return unless File.exist?(path) && changed?(path, original)

          stdout.puts diff_against(path, original)
        end

        def diff_against(path, original)
          Tempfile.create(["metz-orig-", File.basename(path)]) do |orig|
            write_tempfile(orig, original)
            run_diff(orig.path, path)
          end
        end

        def write_tempfile(file, content)
          file.binmode
          file.write(content)
          file.flush
        end

        def run_diff(orig_path, new_path)
          labels = ["--label", "a/#{new_path}", "--label", "b/#{new_path}"]
          Open3.capture3("diff", "-u", *labels, orig_path, new_path).first
        end

        def restore_files(snapshot)
          return unless snapshot

          snapshot.each { |path, content| File.binwrite(path, content) if changed?(path, content) }
        end

        # Only rewrite what RuboCop touched, so an unchanged read-only file cannot abort the restore.
        def changed?(path, original) = !File.exist?(path) || File.binread(path) != original
      end
    end
  end
end
