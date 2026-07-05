# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  class ReadmeProjectAnalyzerStatusTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    PROJECT_ANALYZER_RUNNER = Commands::Scan::ProjectAnalyzerRunner

    def test_readme_status_table_matches_analyzer_constants
      expected_rows = expected_analyzer_rows
      actual_rows = readme_analyzer_rows

      assert_equal expected_rows.keys.sort, actual_rows.keys.sort
      assert_readme_rows_match(expected_rows, actual_rows)
    end

    private

    def expected_analyzer_rows
      PROJECT_ANALYZER_RUNNER::ANALYZERS.to_h do |analyzer|
        [analyzer::RULE_ID, { status: status_label(analyzer), default_scan: default_scan_label(analyzer) }]
      end
    end

    def status_label(analyzer)
      analyzer::PROJECT_ANALYZER_STATUS.split("_").map(&:capitalize).join(" ")
    end

    def default_scan_label(analyzer)
      PROJECT_ANALYZER_RUNNER.default_output_analyzer?(analyzer) ? "Yes" : "No"
    end

    def assert_readme_rows_match(expected_rows, actual_rows)
      expected_rows.each do |rule_id, expected|
        assert_equal expected, actual_rows.fetch(rule_id), "#{rule_id} README row drifted"
      end
    end

    def readme_analyzer_rows
      readme_analyzer_table.each_line.filter_map do |line|
        cells = line.split("|").map(&:strip)
        next unless cells[1]&.start_with?("`MetzProject/")

        [cells[1].delete("`"), { status: cells.fetch(2), default_scan: cells.fetch(3) }]
      end.to_h
    end

    def readme_analyzer_table
      match = File.read(File.join(REPO_ROOT, "README.md")).match(
        /^Current project analyzer status:\n\n(?<table>(?:\|.*\n)+)/
      )
      assert match, "README project analyzer status table is missing"

      match[:table]
    end
  end
end
