# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

module MetzScan
  class ReleaseChecklistTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    CI_PARITY_CHECK = "bin/check_ci_parity"
    CALIBRATION_SMOKE = "bundle exec ruby bin/check_project_analyzer_calibration --text --no-write " \
                        "test/fixtures/sample_app"
    GITHUB_ANNOTATIONS_ASSERTION = "grep -q '^::warning file=.*MetzProject/ServiceSoup'"
    RELEASE_METADATA_SMOKE = "bundle exec ruby -Ilib -Itest test/metz_scan/release_metadata_test.rb"
    RELEASE_ISSUE_SMOKE = "bundle exec ruby -Ilib -Itest test/metz_scan/create_release_issue_test.rb"
    RELEASE_ISSUE_DRY_RUN = "bin/create_release_issue --dry-run"

    def test_issue_template_body_matches_release_checklist
      assert_equal canonical_checklist_body, issue_template_body
    end

    def test_release_checklists_include_calibration_smoke
      release_checklists.each { |path| assert_includes File.read(path), CALIBRATION_SMOKE, path }
    end

    def test_release_checklists_include_release_metadata_smokes
      release_checklists.each { |path| assert_release_metadata_smokes(path) }
    end

    def test_release_checklists_document_issue_dry_run
      release_checklists.each { |path| assert_includes File.read(path), RELEASE_ISSUE_DRY_RUN, path }
    end

    def test_ci_runs_calibration_smoke
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), CALIBRATION_SMOKE
    end

    def test_github_annotations_smoke_is_documented_and_run_by_ci
      release_checklists.each { |path| assert_includes File.read(path), GITHUB_ANNOTATIONS_ASSERTION, path }
      assert_includes File.read(repo_path(".github/workflows/ci.yml")), GITHUB_ANNOTATIONS_ASSERTION
    end

    def test_release_checklists_document_ci_parity_check
      release_checklists.each { |path| assert_includes File.read(path), CI_PARITY_CHECK, path }
    end

    def test_ci_parity_script_covers_ci_single_command_steps
      script = normalized_ruby_script(File.read(repo_path(CI_PARITY_CHECK)))

      refute_empty ci_single_command_steps
      ci_single_command_steps.each { |command| assert_includes script, command }
    end

    private

    def ci_single_command_steps
      workflow = YAML.safe_load_file(repo_path(".github/workflows/ci.yml"))
      steps = workflow.fetch("jobs").fetch("test").fetch("steps")
      steps.filter_map { |step| step["run"]&.strip }.reject { |run| run.include?("\n") }
    end

    def release_checklists
      [repo_path("RELEASE_CHECKLIST.md"), repo_path(".github/ISSUE_TEMPLATE/release_checklist.md")]
    end

    def assert_release_metadata_smokes(path)
      checklist = File.read(path)

      assert_includes checklist, RELEASE_METADATA_SMOKE, path
      assert_includes checklist, RELEASE_ISSUE_SMOKE, path
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

    def normalized_ruby_script(script)
      script.gsub(/"\s*\\\n\s*"/, "")
    end

    def repo_path(path)
      File.join(REPO_ROOT, path)
    end
  end
end
