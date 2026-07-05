# frozen_string_literal: true

require "minitest/autorun"
require "json"

require "metz_scan/calibration/rubydex_drift_formatter"
require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Calibration
    class RubydexDriftFormatterTest < Minitest::Test
      REPO_ROOT = File.expand_path("../../..", __dir__)

      def test_text_output_matches_compact_summary_fixture
        assert_equal fixture("compact_summary_text.txt").chomp, formatter.text
      end

      def test_json_output_matches_compact_summary_fixture
        assert_equal JSON.parse(fixture("compact_summary.json")), JSON.parse(formatter.json)
      end

      private

      def formatter
        RubydexDriftFormatter.new(summary, analyzers: index_backed_rule_ids)
      end

      def summary
        JSON.parse(fixture("compact_summary_input.json"))
      end

      def index_backed_rule_ids
        Commands::Scan::ProjectAnalyzerRunner::INDEX_BACKED_ANALYZERS.map { |analyzer| analyzer::RULE_ID }
      end

      def fixture(name)
        File.read(File.join(REPO_ROOT, "test/fixtures/check_rubydex_drift", name))
      end
    end
  end
end
