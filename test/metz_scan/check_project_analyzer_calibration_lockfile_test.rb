# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

module MetzScan
  class CheckProjectAnalyzerCalibrationLockfileTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_bundle_exec_no_write_calibration_does_not_rewrite_lockfile
      before = File.read(lockfile_path)
      stdout, stderr, status = run_no_write_calibration

      assert_predicate status, :success?, "#{stdout}\n#{stderr}"
      assert_equal before, File.read(lockfile_path)
    end

    private

    def run_no_write_calibration
      Open3.capture3(
        { "BUNDLE_FROZEN" => "1" }, "bundle", "exec", RbConfig.ruby,
        "bin/check_project_analyzer_calibration", "--text", "--no-write",
        "test/fixtures/sample_app", chdir: REPO_ROOT
      )
    end

    def lockfile_path = File.join(REPO_ROOT, "Gemfile.lock")
  end
end
