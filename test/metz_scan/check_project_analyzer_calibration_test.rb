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
    end

    private

    def check_project_analyzer_calibration_path
      File.join(REPO_ROOT, "bin/check_project_analyzer_calibration")
    end
  end
end
