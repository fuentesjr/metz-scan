# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanValidationTest < Minitest::Test
      # The full RuboCop suite can autocorrect this assignment's spacing.
      AUTOCORRECTABLE_SOURCE = "# frozen_string_literal: true\nanswer=1\n"

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-validation-test")
        @original_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.join(@tmpdir, "cache")
      end

      def teardown
        ENV["RUBOCOP_CACHE_ROOT"] = @original_cache_root
        FileUtils.remove_entry(@tmpdir)
      end

      def test_unknown_format_exits_with_usage_error_with_friendly_message
        code = run_scan([@tmpdir, "--format", "bogus"])
        assert_invalid_format_message(code)
      end

      {
        auto_fix: %w[--auto-fix],
        unsafe: %w[--unsafe],
        dry_run: %w[--dry-run],
        all_cops_auto_fix: %w[--all-cops --auto-fix],
        all_cops_auto_fix_dry_run: %w[--all-cops --auto-fix --dry-run]
      }.each do |name, flags|
        define_method("test_scan_rejects_#{name}") { assert_removed_option(flags) }
      end

      def test_nonexistent_path_exits_with_usage_error_with_friendly_message
        path = File.join("/nonexistent", "metz-scan-#{Process.pid}", "path")
        assert_friendly_missing_path(run_scan([path]), path)
      end

      def test_invalid_option_exits_with_usage_error_with_message
        code = run_scan(["--bogus"])

        assert_equal 64, code
        assert_match(/invalid option: --bogus/i, @stderr.string)
        assert_no_stack_trace
      end

      def test_missing_path_exits_with_usage_error_with_message
        code = run_scan([])

        assert_equal 64, code
        assert_match(/missing PATH/i, @stderr.string)
        assert_no_stack_trace
      end

      def test_empty_ruby_project_exits_two_saying_no_files_scanned
        code = run_scan([@tmpdir])

        assert_equal 2, code, "expected exit 2 when no files were scanned (stderr: #{@stderr.string.inspect})"
        assert_includes @stderr.string, "no files scanned"
      end

      def test_help_documents_metz_default_and_all_cops_escape_hatch
        assert_equal 0, run_scan(["--help"])
        assert_includes @stdout.string, "Metz/* cops by default"
        assert_includes @stdout.string, "--all-cops"
      end

      def test_help_documents_baseline_and_omits_removed_fix_flags
        assert_equal 0, run_scan(["--help"])
        assert_match(/--baseline\b/, @stdout.string)
        refute_match(/--(?:auto-fix|unsafe|dry-run)\b/, @stdout.string)
      end

      private

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def assert_removed_option(flags)
        path = File.join(@tmpdir, "sample.rb")
        File.binwrite(path, AUTOCORRECTABLE_SOURCE)

        code = Dir.chdir(@tmpdir) { run_scan([path, *flags]) }

        assert_equal AUTOCORRECTABLE_SOURCE, File.binread(path)
        assert_rejected_option(code, flags)
      end

      def assert_rejected_option(code, flags)
        assert_equal 64, code, "expected scan #{flags.join(' ')} to reject the removed option"
        assert_match(/invalid option: (?:#{Regexp.union(flags - %w[--all-cops])})\b/i, @stderr.string)
        assert_empty @stdout.string
        assert_friendly_scan_usage
      end

      def assert_friendly_scan_usage
        assert_includes @stderr.string, "Usage: metz-scan scan"
        assert_no_stack_trace
      end

      def assert_invalid_format_message(code)
        assert_equal 64, code
        assert_match(/invalid --format/i, @stderr.string)
        Scan::VALID_FORMATS.each { |fmt| assert_match(/#{fmt}/, @stderr.string) }
        assert_no_stack_trace
      end

      def assert_friendly_missing_path(code, path)
        assert_equal 64, code
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
