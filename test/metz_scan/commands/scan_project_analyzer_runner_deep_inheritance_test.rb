# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerDeepInheritanceTest < Minitest::Test
      def test_merges_deep_inheritance_findings_from_project_index
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: deep_inheritance_index)

        assert_deep_inheritance_output(parsed)
      end

      def assert_deep_inheritance_output(parsed)
        assert_deep_inheritance_count(parsed)
        assert_deep_inheritance_path(parsed)
        assert_deep_inheritance_metadata(parsed)
        assert_project_analyzer_summary(parsed)
        assert_summary_counts_match_merged_files(parsed)
      end

      def assert_deep_inheritance_count(parsed)
        assert_equal 1, deep_inheritance_offenses(parsed).size
      end

      def assert_deep_inheritance_path(parsed)
        assert_equal "/app/application_controller.rb", deep_inheritance_file(parsed).fetch("path")
      end

      private

      def assert_summary_counts_match_merged_files(parsed)
        assert_equal parsed.fetch("files").size, parsed.dig("summary", "target_file_count")
        assert_equal parsed.fetch("files").size, parsed.dig("summary", "inspected_file_count")
      end

      def assert_deep_inheritance_metadata(parsed)
        offense = deep_inheritance_offense(parsed)

        assert_deep_inheritance_triage(offense)
        assert_deep_inheritance_identity(offense)
        assert_descendant_metadata(offense)
        assert_report_location_metadata(offense)
      end

      def assert_deep_inheritance_triage(offense)
        assert_equal "validated", offense.dig("project_analyzer", "status")
        assert_equal "low", offense.dig("project_analyzer", "confidence")
        assert_equal "broad base", offense.dig("project_analyzer", "triage_severity")
      end

      def assert_deep_inheritance_identity(offense)
        assert_equal "ApplicationController", offense.dig("project_analyzer", "base_name")
        assert_equal "rails application base", offense.dig("project_analyzer", "root_kind")
      end

      def assert_descendant_metadata(offense)
        assert_equal expected_descendants, offense.dig("project_analyzer", "descendants")
        assert_equal expected_descendants.size, offense.dig("project_analyzer", "descendant_count")
      end

      def assert_report_location_metadata(offense)
        assert_equal "fallback", offense.dig("project_analyzer", "report_location", "line_source")
        assert_equal "ApplicationController", offense.dig("project_analyzer", "report_location", "context")
      end

      def assert_project_analyzer_summary(parsed)
        summary = parsed.fetch("summary").fetch("project_analyzers")

        assert_project_analyzer_counts(summary)
        assert_project_analyzer_rule(summary.fetch("rules").first)
      end

      def assert_project_analyzer_counts(summary)
        assert_equal 1, summary.fetch("finding_count")
        assert_equal 1, summary.fetch("offense_count")
      end

      def assert_project_analyzer_rule(rule)
        assert_equal 1, rule.fetch("offense_count")
        assert_equal "validated", rule.fetch("status")
        assert_equal "low", rule.fetch("confidence")
        assert_equal "broad base", rule.fetch("triage_severity")
      end

      def deep_inheritance_offense(parsed)
        deep_inheritance_offenses(parsed).first
      end

      def deep_inheritance_offenses(parsed)
        offenses(parsed).select { |candidate| candidate.fetch("cop_name") == "MetzProject/DeepInheritanceTree" }
      end

      def deep_inheritance_file(parsed)
        parsed.fetch("files").find do |file|
          file.fetch("offenses").any? { |offense| offense.fetch("cop_name") == "MetzProject/DeepInheritanceTree" }
        end
      end

      def expected_descendants
        %w[AdminController OrdersController ReportsController]
      end

      def offenses(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }
      end

      def deep_inheritance_index
        ProjectAnalyzerRunnerFakeIndex.new(
          "ApplicationController" => expected_descendants,
          "RequestTimeouts" => expected_descendants
        )
      end
    end

    class ScanProjectAnalyzerRunnerDeepInheritanceRootKindTest < Minitest::Test
      def test_preserves_representative_broad_root_categories_in_merged_output
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: broad_root_category_index)

        assert_broad_root_categories(parsed)
        assert_broad_root_category_breakdowns(parsed)
      end

      private

      def assert_broad_root_categories(parsed)
        offenses = deep_inheritance_offenses(parsed)

        assert_equal representative_root_kinds.size, offenses.size
        representative_root_kinds.each do |base_name, root_kind|
          assert_broad_root_category(offenses, base_name, root_kind)
        end
      end

      def assert_broad_root_category(offenses, base_name, root_kind)
        offense = offenses.find { |candidate| candidate.dig("project_analyzer", "base_name") == base_name }

        assert_broad_root_triage(offense)
        assert_equal root_kind, offense.dig("project_analyzer", "root_kind")
        assert_includes offense.fetch("message"), "#{base_name} (#{root_kind}) has 3 descendants"
      end

      def assert_broad_root_triage(offense)
        assert_equal "validated", offense.dig("project_analyzer", "status")
        assert_equal "low", offense.dig("project_analyzer", "confidence")
        assert_equal "broad base", offense.dig("project_analyzer", "triage_severity")
      end

      def assert_broad_root_category_breakdowns(parsed)
        categories = parsed.dig("summary", "project_analyzers", "rules").first
                           .dig("breakdowns", "metadata", "project_analyzer_category")

        representative_root_kinds.values.sort.each do |root_kind|
          assert_includes categories, { "value" => root_kind, "finding_count" => 1 }
        end
      end

      def broad_root_category_index
        ProjectAnalyzerRunnerFakeIndex.new(
          representative_root_kinds.to_h { |base_name, _root_kind| [base_name, descendants_for(base_name)] }
        )
      end

      def representative_root_kinds
        { "ApplicationController" => "rails application base",
          "Api::BaseController" => "controller base",
          "ActivityPub::Serializer" => "serializer base",
          "Jobs::Base" => "application job base",
          "ActiveModel::Serializer" => "framework root" }
      end

      def descendants_for(base_name)
        ["#{base_name}ChildOne", "#{base_name}ChildTwo", "#{base_name}ChildThree"]
      end

      def deep_inheritance_offenses(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }
                       .select { |candidate| candidate.fetch("cop_name") == "MetzProject/DeepInheritanceTree" }
      end
    end

    class ProjectAnalyzerRunnerFakeIndex
      def initialize(descendants)
        @descendants = descendants
      end

      def backend_name = :fake

      def available? = true

      def indexed_files = []

      def declarations
        names = @descendants.flat_map { |base, descendants| [base, *descendants] }.uniq
        names.map { |name| ProjectIndex::Declaration.new(name: name, path: path_for(name), kind: kind_for(name)) }
      end

      def descendants_of(name) = @descendants.fetch(name, [])

      def constant_references_to(_name) = []

      private

      def kind_for(name)
        name == "RequestTimeouts" ? :module : :class
      end

      def path_for(name)
        "/app/#{name.gsub(/([a-z])([A-Z])/, '\\1_\\2').downcase}.rb"
      end
    end
  end
end
