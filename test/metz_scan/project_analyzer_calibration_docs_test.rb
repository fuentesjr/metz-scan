# frozen_string_literal: true

require "minitest/autorun"

module MetzScan
  class ProjectAnalyzerCalibrationDocsTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_docs_include_full_manifest_baseline_example
      assert_docs_include("--targets-file docs/calibration/project_analyzer_targets.yml")
      assert_docs_include("--baseline-file docs/calibration/project_analyzer_baseline.yml")
    end

    def test_docs_explain_filtered_baseline_scope
      assert_docs_include("Filtered `--analyzer` reruns need a matching filtered baseline")
      assert_docs_include("`targets_file`, `default_output`, and `analyzer_filter`")
      assert_docs_include("--analyzer MetzProject/RepeatedBranching")
      assert_docs_include("scope mismatch")
    end

    def test_docs_include_baseline_refresh_preview_example
      assert_docs_include("--print-baseline")
      assert_docs_include("--baseline-label repeated-branching-local")
      assert_docs_include("without writing calibration artifacts")
    end

    def test_docs_include_issue_summary_supported_targets
      assert_docs_include("posting to GitHub")
      assert_docs_include_issue_targets
    end

    private

    def assert_docs_include_issue_targets
      ["#25 (`dogfood`, `dogfood-ci`)", "#27", "`MetzProject/DeepInheritanceTree`",
       "#28", "`MetzProject/RepeatedBranching`"].each { |text| assert_docs_include(text) }
    end

    def assert_docs_include(text)
      assert_includes calibration_docs, text
    end

    def calibration_docs
      @calibration_docs ||= File.read(File.join(REPO_ROOT, "docs/project-analyzer-calibration.md")) +
                            File.read(File.join(REPO_ROOT, "README.md"))
    end
  end
end
