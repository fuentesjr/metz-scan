# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"

module MetzScan
  module Commands
    class Scan
      class AutoFix
        def initialize(stdout:, stderr:)
          @stdout = stdout
          @stderr = stderr
        end

        def run(options)
          require "rubocop-metz"
          options.dry_run ? run_dry(options) : run_in_place(options)
        end

        private

        attr_reader :stdout, :stderr

        def run_in_place(options)
          result = checked_rubocop(options)
          stdout.write(result.stdout)
          stderr.write(result.stderr)
          result.status
        end

        def run_dry(options)
          snapshot = capture_files(options.paths)
          dry_run_result(snapshot, checked_rubocop(options))
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
        def checked_rubocop(options)
          Tempfile.create(["metz-auto-fix-", ".json"]) do |report|
            Runner.capture_output(rubocop_argv(options, report.path)).tap { |result| check!(result, report, options) }
          end
        end

        def check!(result, report, options)
          raise Runner::Error, RubocopFailure.message(result) if RubocopFailure.failed?(result)
          raise CheckFailure::NoFilesScanned, options.paths if inspected_file_count(report.path).zero?
        end

        def inspected_file_count(report_path)
          JSON.parse(File.read(report_path)).dig("summary", "inspected_file_count")
        end

        def rubocop_argv(options, report_path)
          flag = options.unsafe ? "-A" : "-a"
          selection = Runner.cop_selection_argv(options.all_cops)
          selection += ["--disable-pending-cops"] unless options.all_cops
          ["--plugin", "rubocop-metz", *selection, flag, *formatter_argv(report_path), *options.paths]
        end

        # Progress goes last: RuboCop hides cop names when the last --format is json.
        def formatter_argv(report_path) = ["--format", "json", "--out", report_path, "--format", "progress"]

        def capture_files(paths)
          files_under(paths).to_h { |path| [path, File.binread(path)] }
        end

        def files_under(paths)
          paths.flat_map { |path| File.directory?(path) ? regular_files_in(path) : [path] }
        end

        def regular_files_in(dir)
          Dir.glob(File.join(dir, "**/*")).select { |entry| File.file?(entry) }
        end

        def print_diffs(snapshot)
          snapshot.each { |path, original| print_file_diff(path, original) }
        end

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
