# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanValidationTest < Minitest::Test
      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-validation-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_unknown_format_exits_non_zero_with_friendly_message
        code = run_scan([@tmpdir, "--format", "bogus"])
        assert_invalid_format_message(code)
      end

      def test_nonexistent_path_exits_non_zero_with_friendly_message
        path = File.join("/nonexistent", "metz-scan-#{Process.pid}", "path")
        assert_friendly_missing_path(run_scan([path]), path)
      end

      def test_empty_ruby_project_exits_zero
        code = run_scan([@tmpdir])
        assert_equal 0, code, "expected exit 0 on empty project (stderr: #{@stderr.string.inspect})"
      end

      def test_help_documents_metz_default_and_all_cops_escape_hatch
        code = run_scan(["--help"])

        assert_equal 0, code
        assert_includes @stdout.string, "Metz/* cops by default"
        assert_includes @stdout.string, "--all-cops"
      end

      private

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end

      def assert_invalid_format_message(code)
        refute_equal 0, code
        assert_match(/invalid --format/i, @stderr.string)
        Scan::VALID_FORMATS.each { |fmt| assert_match(/#{fmt}/, @stderr.string) }
        assert_no_stack_trace
      end

      def assert_friendly_missing_path(code, path)
        refute_equal 0, code
        assert_match(/#{Regexp.escape(path)}/, @stderr.string)
        assert_match(/no such file/i, @stderr.string)
        assert_no_stack_trace
      end

      def assert_no_stack_trace
        combined = @stdout.string + @stderr.string
        refute_match(/Traceback/, combined, "output should not contain a Ruby traceback")
        refute_match(/\.rb:\d+:in [`']/, combined, "output should not contain a stack frame")
      end
    end
  end
end
