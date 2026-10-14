# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# `scan --auto-fix` follows the same exit contract as a plain scan (owner-approved
# 2026-10-13): a RuboCop error exits 2 with the cause on stderr and nothing on stdout, errors
# win over findings, and a run that checked no files exits 2 without touching any file.
module MetzScan
  module Commands
    class ScanExitAutoFixTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      CAUSES = ["bad.rb", "many_params.rb", "Metz/MethodsTooLong"].freeze

      def test_auto_fix_exits_2_naming_the_cause_when_a_metz_cop_raises
        assert_cop_failure_fails_closed("bad.rb" => SMALL_METHOD) { ["--auto-fix"] }
      end

      def test_auto_fix_dry_run_exits_2_naming_the_cause_when_a_metz_cop_raises
        assert_cop_failure_fails_closed("bad.rb" => SMALL_METHOD) { ["--auto-fix", "--dry-run"] }
      end

      def test_auto_fix_all_cops_exits_2_naming_the_cause_when_a_metz_cop_raises
        assert_cop_failure_fails_closed("bad.rb" => SMALL_METHOD) { ["--auto-fix", "--all-cops"] }
      end

      def test_auto_fix_all_cops_dry_run_exits_2_naming_the_cause_when_a_metz_cop_raises
        assert_cop_failure_fails_closed("bad.rb" => SMALL_METHOD) { ["--auto-fix", "--all-cops", "--dry-run"] }
      end

      # The file also has a Metz/MethodsTooManyParameters offense; the cop error still wins.
      def test_auto_fix_exits_2_rather_than_1_when_a_cop_raises_and_a_metz_finding_exists
        assert_cop_failure_fails_closed("many_params.rb" => TOO_MANY_PARAMETERS) { ["--auto-fix"] }
      end

      def test_auto_fix_dry_run_exits_2_rather_than_1_when_a_cop_raises_and_a_metz_finding_exists
        assert_cop_failure_fails_closed("many_params.rb" => TOO_MANY_PARAMETERS) { ["--auto-fix", "--dry-run"] }
      end

      def test_auto_fix_all_cops_exits_2_rather_than_1_when_a_cop_raises_and_a_metz_finding_exists
        assert_cop_failure_fails_closed("many_params.rb" => TOO_MANY_PARAMETERS) { ["--auto-fix", "--all-cops"] }
      end

      def test_auto_fix_all_cops_dry_run_exits_2_rather_than_1_when_a_cop_raises_and_a_metz_finding_exists
        assert_cop_failure_fails_closed("many_params.rb" => TOO_MANY_PARAMETERS) do
          ["--auto-fix", "--all-cops", "--dry-run"]
        end
      end

      def test_auto_fix_all_cops_exits_2_saying_no_files_scanned_and_changes_nothing_when_only_a_view_remains
        with_excluded_ruby_and_a_view do |dir|
          assert_no_files_scanned_and_unchanged(dir, "--auto-fix", "--all-cops")
        end
      end

      def test_auto_fix_all_cops_dry_run_exits_2_saying_no_files_scanned_and_changes_nothing_when_only_a_view_remains
        with_excluded_ruby_and_a_view do |dir|
          assert_no_files_scanned_and_unchanged(dir, "--auto-fix", "--all-cops", "--dry-run")
        end
      end

      private

      def assert_cop_failure_fails_closed(files)
        with_project(files) do |dir|
          assert_fails_closed(scan_subprocess(dir, ".", *yield, shim: COP_FAILURE_SHIM), *CAUSES)
        end
      end

      # --all-cops keeps RuboCop's own discovery, which never finds the ERB view, so the
      # excluded Ruby file leaves nothing to check. Its stock-cop offense would be
      # rewritten by a wrongful run.
      def with_excluded_ruby_and_a_view(&)
        files = { "excluded/a.rb" => AUTOCORRECTABLE_RUBY, ".rubocop.yml" => EXCLUDE_EVERYTHING_CONFIG,
                  "app/views/users/show.html.erb" => CLEAN_ERB_VIEW }
        with_project(files, &)
      end

      def assert_no_files_scanned_and_unchanged(dir, *)
        before = project_snapshot(dir)

        assert_fails_closed(scan_subprocess(dir, ".", *), "no files scanned")
        assert_equal before, project_snapshot(dir), "no file may change when nothing was scanned"
      end
    end
  end
end
