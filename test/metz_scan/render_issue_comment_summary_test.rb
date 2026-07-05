# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

module MetzScan
  class RenderIssueCommentSummaryTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_renders_parked_analyzer_issue_summary
      stdout, = assert_successful_summary("27")
      assert_deep_inheritance_summary(stdout)
    end

    def test_renders_non_analyzer_issue_summary
      stdout, = assert_successful_summary("25")
      assert_dogfood_summary(stdout)
    end

    def test_rejects_unknown_issue_or_analyzer
      stdout, stderr, status = capture_summary("99")

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes stderr, "unknown issue or analyzer"
    end

    def test_rejects_missing_tracker_boundary
      with_tracker("# Project Tracker\n") do |env|
        assert_missing_boundary_failure(capture_summary("25", env))
      end
    end

    private

    def assert_missing_boundary_failure(result)
      stdout, stderr, status = result
      refute_predicate status, :success?
      assert_empty stdout
      assert_includes stderr, "missing tracker boundary for #25"
    end

    def assert_successful_summary(token)
      stdout, stderr, status = capture_summary(token)
      assert_predicate status, :success?, stderr
      assert_empty stderr
      [stdout, status]
    end

    def assert_deep_inheritance_summary(stdout)
      assert_summary_lines(stdout, deep_inheritance_lines)
      refute_includes stdout, "gh issue comment"
    end

    def assert_dogfood_summary(stdout)
      assert_summary_lines(stdout, dogfood_lines)
    end

    def assert_summary_lines(stdout, lines)
      lines.each { |line| assert_includes stdout, line }
    end

    def deep_inheritance_lines
      ["Issue #27: DeepInheritanceTree", "MetzProject/DeepInheritanceTree", "363 findings",
       "Validated opt-in; not default-output eligible.", "#27 DeepInheritanceTree remains parked"]
    end

    def dogfood_lines
      ["Issue #25: Dogfood CI enforcement", "trigger-gated", "#25 dogfood CI enforcement is trigger-gated"]
    end

    def with_tracker(contents)
      Dir.mktmpdir("metz-scan-issue-summary") do |dir|
        path = File.join(dir, "PROJECT_TRACKER.md")
        File.write(path, contents)
        yield({ "RENDER_ISSUE_COMMENT_TRACKER_PATH" => path })
      end
    end

    def capture_summary(*args)
      env = args.last.is_a?(Hash) ? args.pop : {}
      Open3.capture3(env, render_issue_comment_summary_path, *args, chdir: REPO_ROOT)
    end

    def render_issue_comment_summary_path
      File.join(REPO_ROOT, "bin/render_issue_comment_summary")
    end
  end
end
