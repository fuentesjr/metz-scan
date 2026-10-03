# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/report"

module MetzScan
  module Commands
    class ReportTest < Minitest::Test
      SAMPLE_JSON = {
        "metadata" => { "rubocop_version" => "1.86.1" },
        "files" => [
          { "path" => "app/controllers/users_controller.rb",
            "offenses" => [
              { "cop_name" => "Metz/ControllersTooManyDirectCollaborators",
                "message" => "Action invokes 3 direct collaborators.",
                "severity" => "refactor", "corrected" => false,
                "location" => { "start_line" => 4, "start_column" => 5, "line" => 4, "column" => 5 },
                "why_it_matters" => "Controllers should orchestrate, not implement.",
                "fix_safety" => "manual", "suggested_next_moves" => ["Extract a service object"] },
              { "cop_name" => "Metz/MethodsTooLong",
                "message" => "Method has 8 lines (5 max).",
                "severity" => "refactor", "corrected" => false,
                "location" => { "start_line" => 12, "start_column" => 3 },
                "why_it_matters" => "Long methods hide intent.",
                "fix_safety" => "manual", "suggested_next_moves" => ["Extract a method"] }
            ] }
        ],
        "summary" => { "offense_count" => 2, "target_file_count" => 1, "inspected_file_count" => 1 }
      }.freeze

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-report-test")
        @json_path = File.join(@tmpdir, "report.json")
        File.write(@json_path, JSON.generate(SAMPLE_JSON))
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_text_format_groups_by_cop_with_location_lines
        code = run_report([@json_path])

        refute_equal 0, code
        assert_includes @stdout.string, "Metz/ControllersTooManyDirectCollaborators"
        assert_includes @stdout.string, "Metz/MethodsTooLong"
        assert_equal 2, @stdout.string.scan(/^\s*\S+:\d+:\d+/).size
      end

      def test_sarif_format_emits_sarif_2_1_0_with_results
        code = run_report([@json_path, "--format", "sarif"])
        doc = JSON.parse(@stdout.string)
        refute_equal 0, code
        assert_equal "2.1.0", doc["version"]
        assert_equal 2, doc.dig("runs", 0, "results").size
      end

      def test_json_format_preserves_offense_tuples_and_count
        run_report([@json_path, "--format", "json"])
        out = JSON.parse(@stdout.string)
        assert_equal input_tuples, output_tuples(out)
        assert_equal 2, out["files"].flat_map { |f| f["offenses"] }.size
      end

      def test_clean_json_with_no_offenses_exits_zero
        File.write(@json_path, JSON.generate(empty_report))
        code = run_report([@json_path])

        assert_equal 0, code
      end

      private

      def run_report(argv)
        Report.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def empty_report
        { "metadata" => {}, "files" => [{ "path" => "x.rb", "offenses" => [] }],
          "summary" => { "offense_count" => 0, "target_file_count" => 1, "inspected_file_count" => 1 } }
      end

      def input_tuples
        SAMPLE_JSON["files"].flat_map { |f| f["offenses"].map { |o| tuple(o) } }.sort
      end

      def output_tuples(doc)
        doc["files"].flat_map { |f| f["offenses"].map { |o| tuple(o) } }.sort
      end

      def tuple(offense)
        [offense["cop_name"], offense.dig("location", "start_line"),
         offense.dig("location", "start_column"), offense["message"]]
      end
    end
  end
end
