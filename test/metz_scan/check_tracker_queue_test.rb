# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

module MetzScan
  class CheckTrackerQueueTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_current_tracker_has_actionable_top_queue
      stdout, stderr, status = Open3.capture3(check_tracker_queue_path, chdir: REPO_ROOT)

      assert_predicate status, :success?, stderr
      assert_includes stdout, "check_tracker_queue: ok"
    end

    def test_fails_when_top_queue_is_all_watch_only
      with_tracker(watch_only_tracker) do |path|
        _stdout, stderr, status = Open3.capture3(check_tracker_queue_path, path, chdir: REPO_ROOT)

        refute_predicate status, :success?
        assert_includes stderr, "parked/watch-only"
      end
    end

    def test_passes_when_one_top_item_is_actionable
      with_tracker(actionable_tracker) do |path|
        stdout, stderr, status = Open3.capture3(check_tracker_queue_path, path, chdir: REPO_ROOT)

        assert_predicate status, :success?, stderr
        assert_includes stdout, "check_tracker_queue: ok"
      end
    end

    private

    def watch_only_tracker
      <<~MARKDOWN
        # STATE

        ## Next

        1. Continue package feedback watch.
        2. Keep #25 deferred.
        3. Monitor analyzer evidence.

        ## Backlog
      MARKDOWN
    end

    def actionable_tracker
      <<~MARKDOWN
        # STATE

        ## Next

        1. Keep package feedback watch.
        2. Fix calibration command mutation.
        3. Monitor analyzer evidence.

        ## Backlog
      MARKDOWN
    end

    def with_tracker(contents)
      Dir.mktmpdir("metz-scan-tracker-queue") do |dir|
        path = File.join(dir, "STATE.md")
        File.write(path, contents)
        yield path
      end
    end

    def check_tracker_queue_path = File.join(REPO_ROOT, "bin/check_tracker_queue")
  end
end
