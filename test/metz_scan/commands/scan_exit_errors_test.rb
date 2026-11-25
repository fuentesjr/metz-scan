# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

module MetzScan
  module Commands
    # R3: a crash inside metz-scan itself must not look like "findings reported" (exit 1).
    # Interrupts (130) and usage errors (64) are unchanged and covered elsewhere.
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

    # Exit status contract for `scan` (owner-approved 2026-10-13): any crash in metz-scan
    # itself exits 2 with an "internal error" and backtrace on stderr and nothing on
    # stdout, including exceptions outside StandardError (ScriptError, SystemStackError).
    # Interrupt and explicit exit are out of scope.
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

      private

      def assert_internal_error(result, error_class, message)
        assert_fails_closed(result, "internal error")
        assert_includes result.stderr, error_class, failure_context(result)
        assert_includes result.stderr, message, failure_context(result)
        refute_includes result.stderr, "RuboCop failed", failure_context(result)
        assert_match(/:\d+:in /, result.stderr, "expected a backtrace on stderr\n#{failure_context(result)}")
      end
    end

    # Exit status contract for `scan` (owner-approved 2026-10-13): exit 1 means only
    # "findings reported". RuboCop errors on any file or config exit 2 in both modes,
    # and errors take precedence over findings.
    class ScanExitRubocopErrorsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      # R1a
      def test_default_scan_exits_2_naming_the_cause_when_a_metz_cop_raises
        with_project("bad.rb" => SMALL_METHOD) do |dir|
          result = scan_subprocess(dir, ".", shim: COP_FAILURE_SHIM)

          assert_exit_2_naming(result, "bad.rb", "Metz/MethodsTooLong")
        end
      end

      # R1a
      def test_all_cops_scan_exits_2_naming_the_cause_when_a_metz_cop_raises
        with_project("bad.rb" => SMALL_METHOD) do |dir|
          result = scan_subprocess(dir, ".", "--all-cops", shim: COP_FAILURE_SHIM)

          assert_exit_2_naming(result, "bad.rb", "Metz/MethodsTooLong")
        end
      end

      # R1b
      def test_default_scan_exits_2_naming_the_file_when_a_target_file_cannot_be_read
        with_unreadable_file do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "unreadable.rb")
        end
      end

      # R1b
      def test_all_cops_scan_exits_2_naming_the_file_when_a_target_file_cannot_be_read
        with_unreadable_file do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "unreadable.rb")
        end
      end

      # R1c
      def test_all_cops_scan_exits_2_naming_the_nested_config_when_a_subdirectory_config_is_invalid
        with_nested_broken_config do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "sub/.rubocop.yml")
        end
      end

      # R1d
      def test_default_scan_exits_2_naming_the_nested_config_when_a_subdirectory_config_is_invalid
        with_nested_broken_config do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "sub/.rubocop.yml")
        end
      end

      # R1d: the root-config failure path already worked; keep it working.
      def test_default_scan_still_exits_2_naming_the_config_when_the_root_config_is_invalid
        with_project("a.rb" => CLEAN_RUBY, ".rubocop.yml" => BROKEN_CONFIG) do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), ".rubocop.yml")
        end
      end

      # R1d: same for --all-cops.
      def test_all_cops_scan_still_exits_2_naming_the_config_when_the_root_config_is_invalid
        with_project("a.rb" => CLEAN_RUBY, ".rubocop.yml" => BROKEN_CONFIG) do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), ".rubocop.yml")
        end
      end

      # R2: the file also has a Metz/MethodsTooManyParameters offense; the cop error still wins.
      def test_a_rubocop_cop_error_takes_precedence_over_findings_from_other_cops
        with_project("many_params.rb" => TOO_MANY_PARAMETERS) do |dir|
          result = scan_subprocess(dir, ".", "--format", "json", shim: COP_FAILURE_SHIM)

          assert_exit_2_naming(result, "many_params.rb", "Metz/MethodsTooLong")
        end
      end

      # R2
      def test_an_invalid_nested_config_takes_precedence_over_findings_in_other_files
        files = { "many_params.rb" => TOO_MANY_PARAMETERS, "sub/ok.rb" => CLEAN_RUBY,
                  "sub/.rubocop.yml" => BROKEN_CONFIG }
        with_project(files) do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "sub/.rubocop.yml")
        end
      end

      private

      def with_nested_broken_config(&)
        with_project("a.rb" => CLEAN_RUBY, "sub/b.rb" => CLEAN_RUBY, "sub/.rubocop.yml" => BROKEN_CONFIG, &)
      end

      def with_unreadable_file(&)
        skip "file permissions do not stop root from reading" if Process.euid.zero?
        with_project("ok.rb" => CLEAN_RUBY, "unreadable.rb" => CLEAN_RUBY) { |dir| unreadable(dir, &) }
      end

      def unreadable(dir)
        path = File.join(dir, "unreadable.rb")
        File.chmod(0o000, path)
        yield dir
      ensure
        File.chmod(0o644, path)
      end
    end
  end
end
