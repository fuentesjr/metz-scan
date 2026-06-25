# frozen_string_literal: true

require "digest"
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

      PARSED_WITH_RUBOCOP_OFFENSE = {
        "files" => [
          { "path" => "lib/bar.rb",
            "offenses" => [
              { "cop_name" => "Metz/ControllersTooManyDirectCollaborators",
                "message" => "Action invokes 3 direct collaborators.",
                "severity" => "error",
                "location" => { "start_line" => 10, "start_column" => 2 },
                "why_it_matters" => "Controllers should orchestrate, not implement." }
            ] }
        ]
      }.freeze

      def test_project_analyzer_metadata_survives_as_sarif_result_properties
        result = sarif_results(PARSED).fetch(0)

        assert_equal(
          PARSED.dig("files", 0, "offenses", 0, "project_analyzer"),
          result.dig("properties", "project_analyzer")
        )
      end

      def test_rubocop_result_includes_level_and_reporting_descriptor
        result = sarif_results(PARSED_WITH_RUBOCOP_OFFENSE).fetch(0)

        assert_equal "error", result.fetch("level")
        assert_rubocop_rule_descriptor
      end

      def assert_rubocop_rule_descriptor
        rule = rubocop_rule_descriptor

        assert_equal "Metz/ControllersTooManyDirectCollaborators", rule.fetch("id")
        assert_equal "Action invokes 3 direct collaborators.", rule.dig("shortDescription", "text")
        assert_equal "Controllers should orchestrate, not implement.", rule.dig("fullDescription", "text")
      end

      def test_partial_fingerprints_and_uri_base_id_are_present
        result = sarif_results(PARSED_WITH_RUBOCOP_OFFENSE).fetch(0)

        assert_artifact_location(result)
        assert_equal expected_fingerprint, result.dig("partialFingerprints", "primaryLocationLineHash")
      end

      def test_original_uri_base_ids_includes_root
        doc = sarif_doc(PARSED_WITH_RUBOCOP_OFFENSE)
        root = doc.dig("runs", 0, "originalUriBaseIds", "ROOT", "uri")

        assert root&.start_with?("file://")
      end

      def test_project_analyzer_result_is_included_in_descriptor_set
        rules = sarif_rules(PARSED)

        assert_operator rules.size, :>, 0
        assert(rules.any? { |rule| rule.fetch("id") == "MetzProject/RepeatedBranching" })
      end

      private

      def assert_artifact_location(result)
        artifact_location = result.dig("locations", 0, "physicalLocation", "artifactLocation")
        assert_equal "ROOT", artifact_location.fetch("uriBaseId")
        assert_equal "lib/bar.rb", artifact_location.fetch("uri")
      end

      def expected_fingerprint
        Digest::SHA256.hexdigest(fingerprint_parts.join("|"))
      end

      def fingerprint_parts
        ["Metz/ControllersTooManyDirectCollaborators", "lib/bar.rb", 10, 2,
         "Action invokes 3 direct collaborators."]
      end

      def rubocop_rule_descriptor
        sarif_rules(PARSED_WITH_RUBOCOP_OFFENSE)
          .find { |entry| entry.fetch("id") == "Metz/ControllersTooManyDirectCollaborators" }
      end

      def sarif_doc(parsed)
        stdout = StringIO.new
        Scan::SarifRenderer.new(stdout, parsed).render
        JSON.parse(stdout.string)
      end

      def sarif_results(parsed)
        sarif_doc(parsed).dig("runs", 0, "results")
      end

      def sarif_rules(parsed)
        sarif_doc(parsed).dig("runs", 0, "tool", "driver", "rules")
      end
    end
  end
end
