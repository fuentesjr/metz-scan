# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "timeout"

module MetzScan
  class SigintTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    LARGE_SCAN_TARGET = File.join(REPO_ROOT, "rubocop-metz")

    def test_sigint_during_scan_exits_with_status_130_and_clean_stderr
      status, stderr_output = run_scan_and_interrupt

      assert_clean_exit(status, stderr_output)
      assert_clean_stderr(stderr_output)
    end

    private

    def assert_clean_exit(status, stderr_output)
      assert_equal 130, status.exitstatus,
                   "expected exit status 130 after SIGINT, got #{status.exitstatus.inspect}; stderr=\n#{stderr_output}"
      refute status.signaled?, "process should have exited cleanly, not been signaled"
    end

    def assert_clean_stderr(stderr_output)
      refute_includes stderr_output, "Interrupt"
      refute_includes stderr_output, "Traceback"
      refute_match(/\.rb:\d+:in /, stderr_output)
    end

    def run_scan_and_interrupt
      Open3.popen3(scan_env, *scan_cmd, chdir: REPO_ROOT) do |_in, _out, err, wait_thr|
        sleep 2.0
        Process.kill("INT", wait_thr.pid)
        capture_then_finish(err, wait_thr)
      end
    end

    def scan_cmd
      ["bundle", "exec", "metz-scan", "scan", LARGE_SCAN_TARGET]
    end

    def scan_env
      { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") }
    end

    def capture_then_finish(err, wait_thr)
      stderr_output = String.new
      reader = Thread.new { stderr_output << err.read.to_s }
      wait_for_exit(wait_thr)
      reader.join(2)
      [wait_thr.value, stderr_output]
    end

    def wait_for_exit(wait_thr)
      Timeout.timeout(15) { wait_thr.value }
    rescue Timeout::Error
      Process.kill("KILL", wait_thr.pid)
      raise
    end
  end
end
