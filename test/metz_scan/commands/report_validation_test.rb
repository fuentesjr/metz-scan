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

      WRONG_SHAPE_REPORTS = {
        "array" => "[]",
        "null" => "null",
        "string" => '"str"',
        "empty_object" => "{}",
        "non_array_files" => '{"files":"x"}',
        "non_object_file_entry" => '{"files":["x"]}',
        "non_array_offenses" => '{"files":[{"path":"a.rb","offenses":"x"}]}',
        "sarif" => '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"metz-scan"}},"results":[]}]}'
      }.freeze

      WRONG_SHAPE_REPORTS.each do |label, content|
        define_method("test_#{label}_report_exits_with_usage_error") do
          File.write(@json_path, content)
          code = run_report([@json_path])

          assert_equal 64, code
          assert_equal "metz-scan report: not a metz-scan JSON report: #{@json_path}\n", @stderr.string
          assert_empty @stdout.string
        end
      end

      def test_report_with_no_files_still_renders_clean
        File.write(@json_path, '{"metadata":{},"files":[],"summary":{"offense_count":0}}')
        code = run_report([@json_path])

        assert_equal 0, code
        assert_match(/No offenses found/, @stdout.string)
        assert_empty @stderr.string
      end

      private

      def run_report(argv)
        Report.run(argv, stdout: @stdout, stderr: @stderr)
      end
    end
  end
end
