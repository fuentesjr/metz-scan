# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerDeepInheritanceTest < Minitest::Test
      def test_merges_deep_inheritance_findings_from_project_index
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge(parsed, [], index: deep_inheritance_index)

        assert_includes cop_names(parsed), "MetzProject/DeepInheritanceTree"
        assert_deep_inheritance_metadata(parsed)
        assert_summary_counts_match_merged_files(parsed)
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
        assert_equal expected_descendants, offense.dig("project_analyzer", "descendants")
      end

      def deep_inheritance_offense(parsed)
        offenses(parsed).find { |candidate| candidate.fetch("cop_name") == "MetzProject/DeepInheritanceTree" }
      end

      def expected_descendants
        %w[AdminController OrdersController ReportsController]
      end

      def cop_names(parsed)
        offenses(parsed).map { |offense| offense.fetch("cop_name") }
      end

      def offenses(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }
      end

      def deep_inheritance_index
        ProjectAnalyzerRunnerFakeIndex.new("ApplicationController" => expected_descendants)
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
        names.map { |name| ProjectIndex::Declaration.new(name: name, path: path_for(name)) }
      end

      def descendants_of(name) = @descendants.fetch(name, [])

      private

      def path_for(name)
        "/app/#{name.gsub(/([a-z])([A-Z])/, '\\1_\\2').downcase}.rb"
      end
    end
  end
end
