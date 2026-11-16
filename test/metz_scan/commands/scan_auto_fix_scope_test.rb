# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Default-mode `scan --auto-fix` checks the same files as `scan`: `AllCops: Exclude`
# is honored, `app/views` templates are included, and exit 2 counts from those files.
# Owner decision 2026-10-14, question 29.
module MetzScan
  module Commands
    module ScanAutoFixScopeFixtures
      EXCLUDE_LEGACY_CONFIG = <<~YAML
        AllCops:
          Exclude:
            - "legacy.rb"
      YAML

      ERB_VIEW_PATH = "app/views/users/show.html.erb"
      HAML_VIEW_PATH = "app/views/users/show.html.haml"
      SLIM_VIEW_PATH = "app/views/users/show.html.slim"
      CLEAN_VIEW = "<%= user.name %>\n"
      DEEP_ERB_VIEW = "<%= user.account.owner.email %>\n"
      DEEP_HAML_VIEW = "%p\n  = user.account.owner.email\n"
      DEEP_SLIM_VIEW = "p\n  = user.account.owner.email\n"
    end

    class ScanAutoFixScopeTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures
      include ScanAutoFixScopeFixtures

      def test_default_auto_fix_exits_0_when_only_offending_file_is_excluded
        with_excluded_legacy_project do |dir|
          assert_exit_status 0, scan_subprocess(dir, ".")
          assert_exit_status 0, scan_subprocess(dir, ".", "--auto-fix")
        end
      end

      def test_default_auto_fix_dry_run_exits_0_when_only_offending_file_is_excluded
        with_excluded_legacy_project do |dir|
          assert_exit_status 0, scan_subprocess(dir, ".")
          assert_exit_status 0, scan_subprocess(dir, ".", "--auto-fix", "--dry-run")
        end
      end

      def test_default_auto_fix_exits_2_saying_no_files_scanned_when_all_files_are_excluded
        assert_all_excluded_exits_two("--auto-fix")
      end

      def test_default_auto_fix_dry_run_exits_2_saying_no_files_scanned_when_all_files_are_excluded
        assert_all_excluded_exits_two("--auto-fix", "--dry-run")
      end

      def test_default_auto_fix_exits_0_when_only_a_clean_erb_view_is_not_excluded
        with_excluded_ruby_and_clean_view do |dir|
          assert_exit_status 0, scan_subprocess(dir, ".", "--auto-fix")
        end
      end

      def test_default_auto_fix_dry_run_exits_0_when_only_a_clean_erb_view_is_not_excluded
        with_excluded_ruby_and_clean_view do |dir|
          assert_exit_status 0, scan_subprocess(dir, ".", "--auto-fix", "--dry-run")
        end
      end

      def test_default_auto_fix_exits_1_when_an_erb_view_has_deep_navigation
        assert_view_offense_exits_one(ERB_VIEW_PATH, DEEP_ERB_VIEW, "--auto-fix")
      end

      def test_default_auto_fix_dry_run_exits_1_when_an_erb_view_has_deep_navigation
        assert_view_offense_exits_one(ERB_VIEW_PATH, DEEP_ERB_VIEW, "--auto-fix", "--dry-run")
      end

      def test_default_auto_fix_exits_1_when_a_haml_view_has_deep_navigation
        assert_view_offense_exits_one(HAML_VIEW_PATH, DEEP_HAML_VIEW, "--auto-fix")
      end

      def test_default_auto_fix_exits_1_when_a_slim_view_has_deep_navigation
        assert_view_offense_exits_one(SLIM_VIEW_PATH, DEEP_SLIM_VIEW, "--auto-fix")
      end

      private

      def with_excluded_legacy_project(&)
        files = { ".rubocop.yml" => EXCLUDE_LEGACY_CONFIG, "legacy.rb" => TOO_MANY_PARAMETERS,
                  "clean.rb" => CLEAN_RUBY }
        with_project(files, &)
      end

      def with_excluded_ruby_and_clean_view(&)
        files = { ".rubocop.yml" => EXCLUDE_EVERYTHING_CONFIG, "excluded/a.rb" => TOO_MANY_PARAMETERS,
                  ERB_VIEW_PATH => CLEAN_VIEW }
        with_project(files, &)
      end

      def assert_all_excluded_exits_two(*)
        with_project(".rubocop.yml" => EXCLUDE_EVERYTHING_CONFIG, "excluded/only.rb" => TOO_MANY_PARAMETERS) do |dir|
          before = project_snapshot(dir)
          assert_fails_closed(scan_subprocess(dir, ".", *), "no files scanned")
          assert_equal before, project_snapshot(dir), "excluded files must remain untouched"
        end
      end

      def assert_view_offense_exits_one(path, content, *)
        with_project(path => content) do |dir|
          assert_exit_status 1, scan_subprocess(dir, ".", *)
        end
      end

      def assert_exit_status(expected, result)
        assert_equal expected, result.exitstatus, failure_context(result)
      end
    end
  end
end
