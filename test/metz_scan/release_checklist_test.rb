# frozen_string_literal: true

require "minitest/autorun"

module MetzScan
  class ReleaseChecklistTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    CALIBRATION_SMOKE = "bundle exec ruby bin/check_project_analyzer_calibration --text --no-write " \
                        "test/fixtures/sample_app"
    GITHUB_ANNOTATIONS_ASSERTION = "grep -q '^::warning file=.*MetzProject/ServiceSoup'"

    def test_issue_template_body_matches_release_checklist
      assert_equal canonical_checklist_body, issue_template_body
    end

    def test_release_checklists_include_calibration_smoke
      release_checklists.each { |path| assert_includes File.read(path), CALIBRATION_SMOKE, path }
    end

    def test_ci_runs_calibration_smoke
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), CALIBRATION_SMOKE
    end

    def test_github_annotations_smoke_is_documented_and_run_by_ci
      release_checklists.each { |path| assert_includes File.read(path), GITHUB_ANNOTATIONS_ASSERTION, path }
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), GITHUB_ANNOTATIONS_ASSERTION
    end

    private

    def release_checklists
      [repo_path("RELEASE_CHECKLIST.md"), repo_path(".github/ISSUE_TEMPLATE/release_checklist.md")]
    end

    def canonical_checklist_body
      body_from(File.read(repo_path("RELEASE_CHECKLIST.md")))
    end

    def issue_template_body
      body_from(File.read(repo_path(".github/ISSUE_TEMPLATE/release_checklist.md")))
    end

    def body_from(markdown)
      markdown[markdown.index("## Verification")..]
    end

    def repo_path(path)
      File.join(REPO_ROOT, path)
    end
  end
end
