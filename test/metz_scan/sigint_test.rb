# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "timeout"

module MetzScan
  class SigintTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_sigint_during_entrypoint_startup_exits_with_status_130_and_clean_stderr
      status, stderr_output = run_entrypoint_and_interrupt

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

    def run_entrypoint_and_interrupt
      Open3.popen3(*entrypoint_probe_cmd, chdir: REPO_ROOT) do |_in, out, err, wait_thr|
        await_entrypoint_trap(out)
        send_sigint(wait_thr)
        capture_then_finish(err, wait_thr)
      end
    end

    def entrypoint_probe_cmd
      [RbConfig.ruby, "-Ilib", "-e", entrypoint_probe_script]
    end

    def entrypoint_probe_script
      <<~RUBY
        module Signal
          class << self
            alias_method :metz_scan_original_trap, :trap

            def trap(signal, *command, &block)
              result = metz_scan_original_trap(signal, *command, &block)
              if signal.to_s == "INT"
                STDOUT.sync = true
                puts "ready"
                sleep
              end
              result
            end
          end
        end

        load "bin/metz-scan"
      RUBY
    end

    def capture_then_finish(err, wait_thr)
      stderr_output = String.new
      reader = Thread.new { stderr_output << err.read.to_s }
      wait_for_exit(wait_thr)
      reader.join(2)
      [wait_thr.value, stderr_output]
    end

    def send_sigint(wait_thr)
      Process.kill("INT", wait_thr.pid)
    end

    def await_entrypoint_trap(out)
      Timeout.timeout(5) { assert_equal "ready", out.gets&.strip }
    end

    def wait_for_exit(wait_thr)
      Timeout.timeout(15) { wait_thr.value }
    rescue Timeout::Error
      Process.kill("KILL", wait_thr.pid)
      raise
    end
  end
end
