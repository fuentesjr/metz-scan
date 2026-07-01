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
                  "status" => "validated",
                  "confidence" => "medium",
                  "triage_severity" => "design pressure",
                  "triage_summary" => "Validated repeated-decision signal; review repeated decisions in context."
                } }
            ] },
          { "path" => "lib/workflow.rb",
            "offenses" => [
              { "cop_name" => "MetzProject/ServiceSoup",
                "message" => "OrderWorkflow#call coordinates 3 distinct services.",
                "location" => { "start_line" => 20, "start_column" => 1 },
                "why_it_matters" => "Service-object soup scatters one workflow.",
                "project_analyzer" => {
                  "status" => "validated",
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
              { "cop_name" => "MetzProject/RepeatedBranching", "status" => "validated",
                "confidence" => "medium", "triage_severity" => "design pressure", "finding_count" => 1,
                "offense_count" => 1 },
              { "cop_name" => "MetzProject/ServiceSoup", "status" => "validated",
                "confidence" => "medium", "triage_severity" => "design pressure", "finding_count" => 1,
                "offense_count" => 1 }
            ]
          }
        }
      }.freeze

      def test_project_analyzer_summary_renders_before_rule_blocks
        assert_match(/\AProject analyzers: 2 findings, 2 offenses \(advisory signals; review in context\)/,
                     rendered)
        assert_includes rendered,
                        "MetzProject/RepeatedBranching: 1 finding, 1 offense, status: validated, " \
                        "confidence: medium, severity: design pressure"
      end

      def test_project_analyzer_summary_sorts_same_priority_rules_by_name
        service_summary = rendered.index("MetzProject/ServiceSoup: 1 finding")
        repeated_summary = rendered.index("MetzProject/RepeatedBranching: 1 finding")

        assert_operator repeated_summary, :<, service_summary
      end

      def test_project_analyzer_blocks_keep_normal_cops_first_then_triage_priority
        normal_block = rendered.index("\nMetz/ControllersTooManyDirectCollaborators\n")
        service_block = rendered.index("\nMetzProject/ServiceSoup\n")
        repeated_block = rendered.index("\nMetzProject/RepeatedBranching\n")

        assert_operator normal_block, :<, repeated_block
        assert_operator repeated_block, :<, service_block
      end

      def test_project_analyzer_block_renders_triage_line
        assert_includes rendered, "Triage: status: validated; confidence: medium; severity: design pressure."
        assert_includes rendered, "Validated repeated-decision signal; review repeated decisions in context."
      end

      private

      def rendered
        @rendered ||= rendered_for(PARSED)
      end

      def rendered_for(parsed)
        StringIO.new.tap { |stdout| Scan::TextRenderer.new(stdout, parsed).render }.string
      end
    end

    class ScanTextRendererProjectAnalyzerBreakdownTest < Minitest::Test
      def test_project_analyzer_summary_renders_mixed_triage_breakdowns
        assert_includes rendered,
                        "MetzProject/DeepInheritanceTree: 3 findings, 3 offenses, status: validated, " \
                        "confidence: medium, severity: manual review; mix: severity broad base=2, " \
                        "manual review=1; root_kind controller base=1, rails application base=1"
      end

      private

      def rendered
        StringIO.new.tap { |stdout| Scan::TextRenderer.new(stdout, parsed).render }.string
      end

      def parsed
        { "files" => [], "summary" => { "project_analyzers" => mixed_project_analyzer_summary } }
      end

      def mixed_project_analyzer_summary
        { "finding_count" => 3, "offense_count" => 3, "rules" => [mixed_deep_inheritance_rule] }
      end

      def mixed_deep_inheritance_rule
        { "cop_name" => "MetzProject/DeepInheritanceTree", "status" => "validated",
          "confidence" => "medium", "triage_severity" => "manual review",
          "finding_count" => 3, "offense_count" => 3, "breakdowns" => mixed_breakdowns }
      end

      def mixed_breakdowns
        { "triage_severity" => breakdown("broad base" => 2, "manual review" => 1),
          "metadata" => { "root_kind" => breakdown("controller base" => 1, "rails application base" => 1) } }
      end

      def breakdown(values)
        values.map { |value, count| { "value" => value, "finding_count" => count } }
      end
    end
  end
end
