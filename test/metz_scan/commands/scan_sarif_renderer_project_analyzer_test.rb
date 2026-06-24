# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/sarif_renderer"

module MetzScan
  module Commands
    class ScanSarifRendererProjectAnalyzerTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "lib/foo.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/RepeatedBranching",
                "message" => "Order#status branches in 2 files.",
                "severity" => "refactor",
                "location" => { "start_line" => 10, "start_column" => 1 },
                "project_analyzer" => {
                  "status" => "experimental",
                  "confidence" => "early",
                  "triage_severity" => "manual review",
                  "triage_summary" => "Useful signal, not proof; review repeated decisions in context."
                } }
            ] }
        ]
      }.freeze

      def test_project_analyzer_metadata_survives_as_sarif_result_properties
        result = sarif_results.fetch(0)

        assert_equal(
          PARSED.dig("files", 0, "offenses", 0, "project_analyzer"),
          result.dig("properties", "project_analyzer")
        )
      end

      private

      def sarif_results
        stdout = StringIO.new
        Scan::SarifRenderer.new(stdout, PARSED).render
        JSON.parse(stdout.string).dig("runs", 0, "results")
      end
    end
  end
end
