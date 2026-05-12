# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/cli"

module MetzScan
  module Commands
    class ScanAutoFixProgressTest < Minitest::Test
      FIXTURE = <<~RUBY
        # frozen_string_literal: true

        def f
          x = 1
          y =  2
          return x + y
        end
      RUBY

      def setup
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-progress-test")
        File.write(File.join(@tmpdir, "a.rb"), FIXTURE)
        File.write(File.join(@tmpdir, "b.rb"), FIXTURE)
        File.write(File.join(@tmpdir, "c.rb"), FIXTURE)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_auto_fix_emits_inspecting_progress_line
        output = capture_real_stdout { run_auto_fix }

        assert_match(/Inspecting 3 files/, output, "expected per-file progress line in auto-fix output")
      end

      def test_auto_fix_summary_line_contains_corrected_and_a_numeric_count
        output = capture_real_stdout { run_auto_fix }
        summary = output.lines.last(3).join

        assert_match(/\d+ offenses? corrected/, summary,
                     "expected final summary to mention how many offenses were corrected")
      end

      def test_auto_fix_summary_reports_files_inspected
        output = capture_real_stdout { run_auto_fix }

        assert_match(/3 files? inspected/, output)
      end

      private

      def run_auto_fix
        MetzScan::CLI.start(["scan", @tmpdir, "--auto-fix"], stdout: $stdout, stderr: @stderr)
      end

      def capture_real_stdout(&)
        original = $stdout
        $stdout = StringIO.new
        with_restored_stdout(original, &)
      end

      def with_restored_stdout(original)
        yield
        $stdout.string
      ensure
        $stdout = original
      end
    end
  end
end
