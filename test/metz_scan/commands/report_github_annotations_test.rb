# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/report"

module MetzScan
  module Commands
    class ReportGithubAnnotationsTest < Minitest::Test
      SAMPLE_JSON = {
        "files" => [{ "path" => "app/controllers/users_controller.rb",
                      "offenses" => [{ "cop_name" => "Metz/MethodsTooLong",
                                       "message" => "Method has 8 lines.",
                                       "severity" => "refactor",
                                       "location" => { "start_line" => 12, "start_column" => 3 } }] }],
        "summary" => { "offense_count" => 1 }
      }.freeze

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-report-gh-annotations-test")
        @json_path = File.join(@tmpdir, "report.json")
        File.write(@json_path, JSON.generate(SAMPLE_JSON))
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_github_annotations_format_emits_workflow_commands
        code = run_report([@json_path, "--format", "gh-annotations"])

        refute_equal 0, code
        assert_includes @stdout.string, expected_annotation
      end

      private

      def run_report(argv)
        Report.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def expected_annotation
        "::warning file=app/controllers/users_controller.rb,line=12,col=3," \
          "title=Metz/MethodsTooLong::Method has 8 lines."
      end
    end
  end
end
