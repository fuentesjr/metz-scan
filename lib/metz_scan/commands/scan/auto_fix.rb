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
          RuboCop::CLI.new.run(rubocop_argv(options))
        end

        def run_dry(options)
          snapshot = capture_files(options.paths)
          silent_rubocop(rubocop_argv(options))
          print_diffs(snapshot) and 0
        ensure
          restore_files(snapshot)
        end

        def rubocop_argv(options)
          flag = options.unsafe ? UNSAFE_FLAG : SAFE_FLAG
          ["--plugin", "rubocop-metz", flag, *options.paths]
        end

        def silent_rubocop(argv)
          previous = $stdout
          $stdout = StringIO.new
          RuboCop::CLI.new.run(argv)
        ensure
          $stdout = previous
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
