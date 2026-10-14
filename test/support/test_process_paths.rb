# frozen_string_literal: true

require "fileutils"

module MetzScan
  # Scratch paths owned by one test process, so the parallel slow-test runner
  # (test/support/parallel_test_runner.rb) never lets one process write into,
  # or rmdir, another's directory.
  module TestProcessPaths
    REPO_ROOT = File.expand_path("../..", __dir__)

    module_function

    # At the repo root, not under tmp/: the scans these tests run honor the
    # repo's AllCops Exclude, which covers tmp/ and would hide the fixtures.
    # Tests rmdir it once empty; the runner removes it after a killed process,
    # and every call sweeps dirs left by processes that have since died.
    def scan_tmp_root(pid = Process.pid)
      remove_dead_scan_tmp_roots
      File.join(REPO_ROOT, "scan-test-tmp-#{pid}")
    end

    def remove_dead_scan_tmp_roots
      Dir.glob(File.join(REPO_ROOT, "scan-test-tmp-*")).each do |dir|
        pid = dir[/-(\d+)\z/, 1]
        FileUtils.rm_rf(dir) if pid && !alive?(Integer(pid))
      end
    end

    def alive?(pid)
      Process.kill(0, pid).positive?
    rescue Errno::EPERM
      true
    rescue Errno::ESRCH
      false
    end
  end
end
