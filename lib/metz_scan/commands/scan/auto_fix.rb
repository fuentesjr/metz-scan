# frozen_string_literal: true

require "open3"
require "stringio"
require "tempfile"

module MetzScan
  module Commands
    class Scan
      class AutoFix
        SAFE_FLAG = "-a"
        UNSAFE_FLAG = "-A"
        CommandResult = Struct.new(:status, :stdout, :stderr, keyword_init: true)

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
          with_redirected_io { RuboCop::CLI.new.run(rubocop_argv(options)) }
        end

        def with_redirected_io
          previous = redirect_to(stdout, stderr)
          yield
        ensure
          restore_io(previous) if previous
        end

        def redirect_to(out, err)
          previous = [$stdout, $stderr]
          $stdout = out
          $stderr = err
          previous
        end

        def restore_io(previous)
          $stdout = previous[0]
          $stderr = previous[1]
        end

        def run_dry(options)
          snapshot = capture_files(options.paths)
          dry_run_result(snapshot, capture_rubocop(rubocop_argv(options)))
        ensure
          restore_files(snapshot)
        end

        def dry_run_result(snapshot, result)
          print_diffs(snapshot)
          print_rubocop_failure(result) unless result.status.zero?
          result.status
        end

        def rubocop_argv(options)
          flag = options.unsafe ? UNSAFE_FLAG : SAFE_FLAG
          ["--plugin", "rubocop-metz", flag, *options.paths]
        end

        def capture_rubocop(argv)
          out = StringIO.new
          err = StringIO.new
          status = with_captured_io(out, err) { RuboCop::CLI.new.run(argv) }
          CommandResult.new(status: status, stdout: out.string, stderr: err.string)
        end

        def with_captured_io(out, err)
          previous = redirect_to(out, err)
          yield
        ensure
          restore_io(previous) if previous
        end

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
          return unless File.exist?(path)
          return if File.binread(path) == original

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

          snapshot.each { |path, content| File.binwrite(path, content) }
        end
      end
    end
  end
end
