# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/text_renderer"

module MetzScan
  module Commands
    class ScanTextRendererProjectAnalyzerPriorityTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "app/services/spree/seeds/all.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/ServiceSoup",
                "message" => "Spree::Seeds::All#call coordinates 15 distinct services.",
                "location" => { "start_line" => 10, "start_column" => 1 },
                "why_it_matters" => "Setup orchestration often intentionally runs a list of tasks.",
                "project_analyzer" => {
                  "status" => "validated",
                  "confidence" => "low",
                  "triage_severity" => "setup orchestration",
                  "triage_summary" => "Setup workflow signal; review only when setup orchestration changes often."
                } }
            ] },
          { "path" => "app/services/orders/create.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/ServiceSoup",
                "message" => "Orders::Create#call coordinates 3 distinct services.",
                "location" => { "start_line" => 20, "start_column" => 1 },
                "why_it_matters" => "Service-object soup scatters one workflow.",
                "project_analyzer" => {
                  "status" => "validated",
                  "confidence" => "medium",
                  "triage_severity" => "design pressure",
                  "triage_summary" => "Validated workflow signal; review methods that coordinate several " \
                                      "distinct services."
                } }
            ] },
          { "path" => "app/services/zed.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/Zed",
                "message" => "Zed#call coordinates 3 distinct services.",
                "location" => { "start_line" => 30, "start_column" => 1 },
                "why_it_matters" => "Another validated analyzer finding.",
                "project_analyzer" => {
                  "status" => "validated",
                  "confidence" => "medium",
                  "triage_severity" => "design pressure",
                  "triage_summary" => "Validated workflow signal."
                } }
            ] }
        ],
        "summary" => {}
      }.freeze

      def test_block_uses_highest_priority_triage_for_mixed_rule_findings
        assert_includes rendered, "Triage: status: validated; confidence: medium; severity: design pressure."
        refute_includes rendered, "confidence: low; severity: setup orchestration"
      end

      def test_block_sorting_uses_highest_priority_triage_for_mixed_rule_findings
        assert_operator rendered.index("MetzProject/ServiceSoup\n"), :<, rendered.index("MetzProject/Zed\n")
      end

      private

      def rendered
        @rendered ||= StringIO.new.tap { |stdout| Scan::TextRenderer.new(stdout, PARSED).render }.string
      end
    end
  end
end
