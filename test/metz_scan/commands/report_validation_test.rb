# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/report"

module MetzScan
  module Commands
    class ReportValidationTest < Minitest::Test
      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-report-validation-test")
        @json_path = File.join(@tmpdir, "report.json")
        File.write(@json_path, "{}")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_missing_file_exits_with_usage_error_with_friendly_message
        code = run_report(["/tmp/does-not-exist-#{Process.pid}.json"])

        assert_equal 64, code
        assert_match(%r{/tmp/does-not-exist-#{Process.pid}\.json}, @stderr.string)
        assert_match(/no such file/i, @stderr.string)
        refute_match(/\.rb:\d+:in /, @stderr.string)
      end

      def test_invalid_json_exits_with_usage_error_with_parse_message
        File.write(@json_path, "not json {{")
        code = run_report([@json_path])

        assert_equal 64, code
        assert_match(/invalid JSON|parse/i, @stderr.string)
        refute_match(/\.rb:\d+:in /, @stderr.string)
      end

      def test_invalid_format_exits_with_usage_error
        code = run_report([@json_path, "--format", "bogus"])

        assert_equal 64, code
        assert_match(/invalid --format/i, @stderr.string)
      end

      def test_missing_path_argument_exits_with_usage_error_with_usage
        code = run_report([])

        assert_equal 64, code
        assert_match(/missing PATH/i, @stderr.string)
      end

      def test_invalid_option_exits_with_usage_error_with_usage
        code = run_report(["--bogus"])

        assert_equal 64, code
        assert_match(/invalid option: --bogus/i, @stderr.string)
      end

      private

      def run_report(argv)
        Report.run(argv, stdout: @stdout, stderr: @stderr)
      end
    end
  end
end
