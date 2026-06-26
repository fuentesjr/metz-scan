# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/commands/scan/text_renderer"

module MetzScan
  module Commands
    class ScanTextRendererProjectAnalyzerTest < Minitest::Test
      PARSED = {
        "files" => [
          { "path" => "app/controllers/orders_controller.rb",
            "offenses" => [
              { "cop_name" => "Metz/ControllersTooManyDirectCollaborators",
                "message" => "Action invokes 3 direct collaborators.",
                "location" => { "start_line" => 5, "start_column" => 1 },
                "why_it_matters" => "Controllers should orchestrate, not implement." }
            ] },
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
            ] },
          { "path" => "lib/workflow.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/ServiceSoup",
                "message" => "OrderWorkflow#call coordinates 3 distinct services.",
                "location" => { "start_line" => 20, "start_column" => 1 },
                "why_it_matters" => "Service-object soup scatters one workflow.",
                "project_analyzer" => {
                  "status" => "candidate",
                  "confidence" => "medium",
                  "triage_severity" => "design pressure",
                  "triage_summary" => "Candidate workflow signal; review methods that coordinate several " \
                                      "distinct services."
                } }
            ] }
        ],
        "summary" => {
          "project_analyzers" => {
            "finding_count" => 2,
            "offense_count" => 2,
            "rules" => [
              { "cop_name" => "MetzProject/RepeatedBranching", "status" => "experimental",
                "confidence" => "early", "triage_severity" => "manual review", "finding_count" => 1,
                "offense_count" => 1 },
              { "cop_name" => "MetzProject/ServiceSoup", "status" => "candidate",
                "confidence" => "medium", "triage_severity" => "design pressure", "finding_count" => 1,
                "offense_count" => 1 }
            ]
          }
        }
      }.freeze

      def test_project_analyzer_summary_renders_before_rule_blocks
        assert_match(/\AProject analyzers: 2 findings, 2 offenses \(opt-in advisory signals; review in context\)/,
                     rendered)
        assert_includes rendered,
                        "MetzProject/RepeatedBranching: 1 finding, 1 offense, status: experimental, " \
                        "confidence: early, severity: manual review"
      end

      def test_project_analyzer_summary_lists_candidate_rules_first
        service_summary = rendered.index("MetzProject/ServiceSoup: 1 finding")
        repeated_summary = rendered.index("MetzProject/RepeatedBranching: 1 finding")

        assert_operator service_summary, :<, repeated_summary
      end

      def test_project_analyzer_blocks_keep_normal_cops_first_then_triage_priority
        normal_block = rendered.index("\nMetz/ControllersTooManyDirectCollaborators\n")
        service_block = rendered.index("\nMetzProject/ServiceSoup\n")
        repeated_block = rendered.index("\nMetzProject/RepeatedBranching\n")

        assert_operator normal_block, :<, service_block
        assert_operator service_block, :<, repeated_block
      end

      def test_project_analyzer_block_renders_triage_line
        assert_includes rendered, "Triage: status: experimental; confidence: early; severity: manual review."
        assert_includes rendered, "Useful signal, not proof; review repeated decisions in context."
      end

      private

      def rendered
        @rendered ||= rendered_for(PARSED)
      end

      def rendered_for(parsed)
        StringIO.new.tap { |stdout| Scan::TextRenderer.new(stdout, parsed).render }.string
      end
    end
  end
end
