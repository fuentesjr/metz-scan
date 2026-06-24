# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/text_renderer"

module MetzScan
  module Commands
    class ScanTextRendererProjectAnalyzerTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "lib/foo.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/RepeatedBranching",
                "message" => "Order#status branches in 2 files.",
                "location" => { "start_line" => 10, "start_column" => 1 },
                "why_it_matters" => "Repeated branching spreads one domain decision.",
                "project_analyzer" => {
                  "status" => "experimental",
                  "confidence" => "early",
                  "triage_severity" => "manual review",
                  "triage_summary" => "Useful signal, not proof; review repeated decisions in context."
                } }
            ] }
        ],
        "summary" => {
          "project_analyzers" => {
            "finding_count" => 1,
            "offense_count" => 1,
            "rules" => [
              { "cop_name" => "MetzProject/RepeatedBranching", "status" => "experimental",
                "confidence" => "early", "triage_severity" => "manual review",
                "finding_count" => 1, "offense_count" => 1 }
            ]
          }
        }
      }.freeze

      def test_project_analyzer_summary_renders_before_rule_blocks
        assert_match(/\AProject analyzers: 1 finding, 1 offense \(opt-in advisory signals; review in context\)/,
                     rendered)
        assert_includes rendered,
                        "MetzProject/RepeatedBranching: 1 finding, 1 offense, status: experimental, " \
                        "confidence: early, severity: manual review"
      end

      def test_project_analyzer_block_renders_triage_line
        assert_includes rendered, "Triage: status: experimental; confidence: early; severity: manual review."
        assert_includes rendered, "Useful signal, not proof; review repeated decisions in context."
      end

      private

      def rendered
        @rendered ||= StringIO.new.tap { |stdout| Scan::TextRenderer.new(stdout, PARSED).render }.string
      end
    end
  end
end
