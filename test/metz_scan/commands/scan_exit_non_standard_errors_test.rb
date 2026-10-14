# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Exit status contract for `scan` (owner-approved 2026-10-13): any crash in metz-scan
# itself exits 2 with an "internal error" and backtrace on stderr and nothing on
# stdout, including exceptions outside StandardError (ScriptError, SystemStackError).
# Interrupt and explicit exit are out of scope.
module MetzScan
  module Commands
    class ScanExitNonStandardErrorsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      def test_a_not_implemented_error_in_the_scan_summary_step_exits_2_as_an_internal_error
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          result = scan_subprocess(dir, ".", shim: NOT_IMPLEMENTED_SHIM)

          assert_internal_error(result, "NotImplementedError", "injected not-implemented failure")
        end
      end

      def test_a_system_stack_error_in_the_scan_summary_step_exits_2_as_an_internal_error
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          result = scan_subprocess(dir, ".", shim: STACK_OVERFLOW_SHIM)

          assert_internal_error(result, "SystemStackError", "injected stack failure")
        end
      end

      def test_a_load_error_when_auto_fix_starts_exits_2_as_an_internal_error
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          result = scan_subprocess(dir, ".", "--auto-fix", shim: AUTO_FIX_LOAD_ERROR_SHIM)

          assert_internal_error(result, "LoadError", "injected load failure")
        end
      end

      private

      def assert_internal_error(result, error_class, message)
        assert_fails_closed(result, "internal error")
        assert_includes result.stderr, error_class, failure_context(result)
        assert_includes result.stderr, message, failure_context(result)
        refute_includes result.stderr, "RuboCop failed", failure_context(result)
        assert_match(/:\d+:in /, result.stderr, "expected a backtrace on stderr\n#{failure_context(result)}")
      end
    end
  end
end
