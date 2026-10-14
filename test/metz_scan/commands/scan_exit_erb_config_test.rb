# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Exit status contract for `scan` (owner-approved 2026-10-13): RuboCop errors and
# crashes exit 2 with the cause on stderr and nothing on stdout. RuboCop evaluates
# ERB in `.rubocop.yml` before parsing it, so an ERB failure is a configuration
# failure ("RuboCop failed: ..."), never an "internal error" with a backtrace, and
# never exit 1 ("findings reported"). Observed 2026-10-14: a root `<% if %>` made
# the default-mode scan crash with exit 1; `<%= no_such_helper %>` exited 2 but
# was reported as an internal error with a Ruby backtrace.
module MetzScan
  module Commands
    class ScanExitErbConfigTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      ERB_SYNTAX_ERROR_CONFIG = "<% if %>\nAllCops:\n  SuggestExtensions: false\n"
      ERB_RUNTIME_ERROR_CONFIG = "AllCops:\n  TargetRubyVersion: <%= no_such_helper %>\n"
      VALID_CONFIG = "AllCops:\n  SuggestExtensions: false\n"

      CASES = {
        "a_root_config_with_an_erb_syntax_error" =>
          [{ ".rubocop.yml" => ERB_SYNTAX_ERROR_CONFIG, "a.rb" => CLEAN_RUBY }, "syntax"],
        "a_root_config_whose_erb_raises_at_runtime" =>
          [{ ".rubocop.yml" => ERB_RUNTIME_ERROR_CONFIG, "a.rb" => CLEAN_RUBY }, "no_such_helper"],
        "a_nested_config_with_an_erb_syntax_error" =>
          [{ ".rubocop.yml" => VALID_CONFIG, "a.rb" => CLEAN_RUBY, "sub/b.rb" => CLEAN_RUBY,
             "sub/.rubocop.yml" => ERB_SYNTAX_ERROR_CONFIG }, "syntax"]
      }.freeze

      CASES.each do |name, (files, cause)|
        define_method("test_default_scan_exits_2_as_a_configuration_failure_for_#{name}") do
          with_project(files) { |dir| assert_configuration_failure(scan_subprocess(dir, "."), cause) }
        end

        define_method("test_all_cops_scan_exits_2_as_a_configuration_failure_for_#{name}") do
          with_project(files) { |dir| assert_configuration_failure(scan_subprocess(dir, ".", "--all-cops"), cause) }
        end
      end

      private

      def assert_configuration_failure(result, cause)
        assert_fails_closed(result, cause)
        assert_includes result.stderr, "RuboCop failed", failure_context(result)
        refute_includes result.stderr, "internal error", failure_context(result)
        refute_match(/\.rb:\d+:in /, result.stderr, "expected no Ruby backtrace on stderr\n#{failure_context(result)}")
      end
    end
  end
end
