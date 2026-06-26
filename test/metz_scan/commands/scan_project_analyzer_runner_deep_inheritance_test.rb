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

        assert_equal "experimental", offense.dig("project_analyzer", "status")
        assert_equal "ApplicationController", offense.dig("project_analyzer", "base_name")
        assert_descendant_metadata(offense)
        assert_report_location_metadata(offense)
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

        assert_equal 1, summary.fetch("finding_count")
        assert_equal 1, summary.fetch("offense_count")
        assert_equal 1, summary.fetch("rules").first.fetch("offense_count")
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
