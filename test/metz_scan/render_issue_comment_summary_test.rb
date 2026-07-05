# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

module MetzScan
  class RenderIssueCommentSummaryTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_renders_parked_analyzer_issue_summary
      assert_fixture_summary("27", "issue_27.txt")
    end

    def test_renders_non_analyzer_issue_summary
      assert_fixture_summary("25", "issue_25.txt")
    end

    def test_renders_non_analyzer_issue_summary_by_alias
      assert_fixture_summary("dogfood-ci", "issue_25.txt")
    end

    def test_renders_repeated_branching_issue_summary
      assert_fixture_summary("28", "issue_28.txt")
    end

    def test_renders_repeated_branching_issue_summary_by_analyzer_name
      assert_fixture_summary("MetzProject/RepeatedBranching", "issue_28.txt")
    end

    def test_help_lists_supported_targets_and_local_boundary
      stdout, stderr, status = capture_summary("--help")

      assert_predicate status, :success?, stderr
      assert_empty stderr
      assert_help_targets(stdout)
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

    def assert_fixture_summary(token, fixture_name)
      stdout, = assert_successful_summary(token)

      assert_equal fixture(fixture_name), stdout
    end

    def assert_successful_summary(token)
      stdout, stderr, status = capture_summary(token)
      assert_predicate status, :success?, stderr
      assert_empty stderr
      [stdout, status]
    end

    def assert_help_targets(stdout)
      ["Supported targets:", "25, dogfood, dogfood-ci", "27,", "deep-inheritance-tree",
       "MetzProject/DeepInheritanceTree", "28,", "repeated-branching", "MetzProject/RepeatedBranching",
       "no GitHub comment is posted"].each { |line| assert_includes stdout, line }
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

    def fixture(name)
      File.read(File.join(REPO_ROOT, "test/fixtures/render_issue_comment_summary", name))
    end
  end
end
