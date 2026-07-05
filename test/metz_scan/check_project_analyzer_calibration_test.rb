# frozen_string_literal: true

require "minitest/autorun"
require "open3"

module MetzScan
  class CheckProjectAnalyzerCalibrationTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_help_documents_baseline_scope_matching
      stdout, stderr, status = Open3.capture3(check_project_analyzer_calibration_path, "--help")

      assert_predicate status, :success?, stderr
      assert_includes stdout, "--baseline-file"
      assert_includes stdout, "run scope must match"
      assert_help_examples(stdout)
    end

    private

    def assert_help_examples(stdout)
      assert_includes stdout, "--baseline-file docs/calibration/project_analyzer_baseline.yml"
      assert_includes stdout, "--print-baseline"
      assert_includes stdout, "--baseline-label repeated-branching-local"
      assert_includes stdout, "targets_file, default_output,"
      assert_includes stdout, "and analyzer_filter match the current run"
    end

    def check_project_analyzer_calibration_path
      File.join(REPO_ROOT, "bin/check_project_analyzer_calibration")
    end
  end
end
