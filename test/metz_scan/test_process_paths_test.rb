# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "rbconfig"
require "support/test_process_paths"

module MetzScan
  class TestProcessPathsTest < Minitest::Test
    def setup
      @dead_pid = Process.spawn(RbConfig.ruby, "-e", "exit")
      Process.wait(@dead_pid)
      @live_pid = Process.spawn("sleep", "60")
      [@dead_pid, @live_pid].each { |pid| FileUtils.mkdir_p(scratch(pid)) }
    end

    def teardown
      Process.kill("KILL", @live_pid)
      Process.wait(@live_pid)
      [@dead_pid, @live_pid].each { |pid| FileUtils.rm_rf(scratch(pid)) }
    end

    def test_scan_tmp_root_removes_scratch_dirs_of_dead_processes_only
      TestProcessPaths.scan_tmp_root

      refute_path_exists scratch(@dead_pid)
      assert_path_exists scratch(@live_pid)
    end

    private

    def scratch(pid) = File.join(TestProcessPaths::REPO_ROOT, "scan-test-tmp-#{pid}")
  end
end
