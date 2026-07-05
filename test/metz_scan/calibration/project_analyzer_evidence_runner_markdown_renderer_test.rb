# frozen_string_literal: true

require "json"
require "minitest/autorun"

require "metz_scan/calibration/project_analyzer_evidence_runner"

module MetzScan
  module Calibration
    class ProjectAnalyzerEvidenceRunnerMarkdownRendererTest < Minitest::Test
      def test_renders_representative_summary_exactly
        rendered = ProjectAnalyzerEvidenceRunner::MarkdownRenderer.new(summary).call

        assert_equal expected_markdown, rendered
      end

      def test_renders_baseline_delta_summary_exactly
        rendered = ProjectAnalyzerEvidenceRunner::MarkdownRenderer.new(baseline_delta_summary).call

        assert_equal baseline_delta_markdown, rendered
      end

      private

      def summary
        JSON.parse(File.read(fixture_path("representative_summary.json")))
      end

      def baseline_delta_summary
        JSON.parse(File.read(fixture_path("baseline_delta_summary.json")))
      end

      def expected_markdown
        File.read(fixture_path("representative_summary.md"))
      end

      def baseline_delta_markdown
        File.read(fixture_path("baseline_delta_summary.md"))
      end

      def fixture_path(name)
        File.expand_path("../../fixtures/project_analyzer_evidence_runner/#{name}", __dir__)
      end
    end
  end
end
