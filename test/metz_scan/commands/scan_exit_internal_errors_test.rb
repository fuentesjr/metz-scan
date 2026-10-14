# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# R3: a crash inside metz-scan itself must not look like "findings reported" (exit 1).
# Interrupts (130) and usage errors (64) are unchanged and covered elsewhere.
module MetzScan
  module Commands
    class ScanExitInternalErrorsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      # R3
      def test_a_project_analyzer_crash_exits_2_naming_the_exception_message
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          result = scan_subprocess(dir, ".", shim: ANALYZER_FAILURE_SHIM)

          assert_exit_2_naming(result, "injected analyzer failure")
        end
      end

      # R3
      def test_a_crash_in_the_scan_pipeline_outside_rubocop_exits_2_naming_the_exception_message
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          result = scan_subprocess(dir, ".", shim: PIPELINE_FAILURE_SHIM)

          assert_exit_2_naming(result, "injected pipeline failure")
        end
      end

      # A metz-scan crash while the RuboCop step runs is not a RuboCop failure: it is
      # reported as an internal error, with the exception message and a backtrace.
      def test_a_crash_in_metz_scan_during_the_rubocop_step_is_reported_as_an_internal_error_with_a_backtrace
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          assert_internal_error(scan_subprocess(dir, ".", shim: LEDGER_FAILURE_SHIM), "injected ledger failure")
        end
      end

      # R2: RuboCop reports a Metz/MethodsTooManyParameters offense; the crash still wins.
      def test_a_project_analyzer_crash_takes_precedence_over_rubocop_findings
        with_project("many_params.rb" => TOO_MANY_PARAMETERS) do |dir|
          result = scan_subprocess(dir, ".", shim: ANALYZER_FAILURE_SHIM)

          assert_exit_2_naming(result, "injected analyzer failure")
        end
      end

      private

      def assert_internal_error(result, message)
        assert_fails_closed(result, message)
        refute_includes result.stderr, "RuboCop failed", failure_context(result)
        assert_match(/:\d+:in /, result.stderr, "expected a backtrace on stderr\n#{failure_context(result)}")
      end
    end
  end
end
