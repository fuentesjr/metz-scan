# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# `scan --auto-fix` follows the scan exit contract (owner-approved 2026-10-13): when it
# could not check the code it exits 2, the cause goes to stderr, and stdout gets nothing.
# Which files default-mode auto-fix checks is an open owner question and is not pinned here.
module MetzScan
  module Commands
    class ScanExitAutoFixFailuresTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      ERB_RUNTIME_ERROR_CONFIG = "AllCops:\n  TargetRubyVersion: <%= no_such_helper %>\n"

      # RuboCop records an autocorrect that never converges as an error, not as a cop crash.
      def test_auto_fix_exits_2_naming_the_file_and_cop_on_a_nonconverging_autocorrect
        assert_infinite_loop_fails_closed("--auto-fix")
      end

      def test_auto_fix_all_cops_exits_2_naming_the_file_and_cop_on_a_nonconverging_autocorrect
        assert_infinite_loop_fails_closed("--auto-fix", "--all-cops")
      end

      def test_auto_fix_dry_run_exits_2_naming_file_and_cop_and_changes_nothing_on_a_nonconverging_autocorrect
        assert_infinite_loop_fails_closed("--auto-fix", "--dry-run", unchanged: true)
      end

      def test_auto_fix_all_cops_dry_run_exits_2_naming_file_and_cop_and_changes_nothing_on_a_nonconverging_autocorrect
        assert_infinite_loop_fails_closed("--auto-fix", "--all-cops", "--dry-run", unchanged: true)
      end

      CONFIG_CASES = {
        "a_root_config_with_a_yaml_syntax_error" =>
          [{ ".rubocop.yml" => BROKEN_CONFIG, "a.rb" => CLEAN_RUBY }, ".rubocop.yml"],
        "a_nested_config_with_a_yaml_syntax_error" =>
          [{ "a.rb" => CLEAN_RUBY, "sub/b.rb" => CLEAN_RUBY, "sub/.rubocop.yml" => BROKEN_CONFIG }, "sub/.rubocop.yml"],
        "a_root_config_whose_erb_fails_to_evaluate" =>
          [{ ".rubocop.yml" => ERB_RUNTIME_ERROR_CONFIG, "a.rb" => CLEAN_RUBY }, "no_such_helper"]
      }.freeze

      CONFIG_CASES.each do |name, (files, cause)|
        define_method("test_default_auto_fix_exits_2_as_a_configuration_failure_for_#{name}") do
          with_project(files) { |dir| assert_configuration_failure(dir, cause, "--auto-fix") }
        end

        define_method("test_default_auto_fix_dry_run_exits_2_as_a_config_failure_and_changes_nothing_for_#{name}") do
          with_project(files) do |dir|
            before = project_snapshot(dir)

            assert_configuration_failure(dir, cause, "--auto-fix", "--dry-run")
            assert_equal before, project_snapshot(dir), "a dry run must leave every file unchanged"
          end
        end
      end

      private

      # The file state after an in-place run is not pinned: RuboCop may already have rewritten it.
      def assert_infinite_loop_fails_closed(*flags, unchanged: false)
        with_project("bad.rb" => SMALL_METHOD) do |dir|
          before = project_snapshot(dir)
          assert_names_file_and_cop(scan_subprocess(dir, ".", *flags, shim: INFINITE_CORRECTION_SHIM))
          assert_equal before, project_snapshot(dir), "a dry run must leave the file byte-identical" if unchanged
        end
      end

      def assert_names_file_and_cop(result)
        assert_fails_closed(result, "bad.rb")
        assert_includes result.stderr, "Metz/MethodsTooLong", failure_context(result)
      end

      def assert_configuration_failure(dir, cause, *flags)
        result = scan_subprocess(dir, ".", *flags)

        assert_fails_closed(result, cause)
        assert_includes result.stderr, "RuboCop failed", failure_context(result)
        refute_includes result.stderr, "internal error", failure_context(result)
        refute_match(/\.rb:\d+:in /, result.stderr, "expected no Ruby backtrace on stderr\n#{failure_context(result)}")
      end
    end
  end
end
