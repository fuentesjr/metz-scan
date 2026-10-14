# frozen_string_literal: true

module MetzScan
  module TestFileGroups
    ALL_PATTERNS = [
      "rubocop-metz/test/**/*_test.rb",
      "test/**/*_test.rb"
    ].freeze
    SLOW_PATTERNS = [
      "rubocop-metz/test/integration/**/*_test.rb",
      "rubocop-metz/test/cop/metz/views_deep_navigation_test.rb",
      "test/metz_scan/check_ci_parity_test.rb",
      "test/metz_scan/check_dogfood_test.rb",
      "test/metz_scan/check_published_gem_failure_test.rb",
      "test/metz_scan/check_published_gem_test.rb",
      "test/metz_scan/check_project_analyzer_calibration_lockfile_test.rb",
      "test/metz_scan/check_read_only_commands_test.rb",
      "test/metz_scan/check_rubydex_drift_test.rb",
      "test/metz_scan/check_tracker_queue_test.rb",
      "test/metz_scan/parallel_test_runner_test.rb",
      "test/metz_scan/sigint_test.rb",
      "test/metz_scan/commands/scan_analyzer_*_test.rb",
      "test/metz_scan/commands/scan_auto_fix*_test.rb",
      "test/metz_scan/commands/scan_config_disabled_test.rb",
      "test/metz_scan/commands/scan_directory_view_templates_test.rb",
      "test/metz_scan/commands/scan_error_test.rb",
      "test/metz_scan/commands/scan_exit_*_test.rb",
      "test/metz_scan/commands/scan_github_annotations_format_test.rb",
      "test/metz_scan/commands/scan_json_guidance_test.rb",
      "test/metz_scan/commands/scan_path_scoped_include_note_test.rb",
      "test/metz_scan/commands/scan_project_analyzers_test.rb",
      "test/metz_scan/commands/scan_rails_aware_include_test.rb",
      "test/metz_scan/commands/scan_regexp_exclude_test.rb",
      "test/metz_scan/commands/scan_stock_guidance_scope_test.rb",
      "test/metz_scan/commands/scan_suppression_ledger_test.rb",
      "test/metz_scan/commands/scan_test.rb"
    ].freeze
    # Slow files measured at 9s or more (2026-10-14, serial), longest first. The
    # parallel runner starts these before the rest so the longest file does
    # not start last; file size was a poor proxy for duration. Re-measure with
    # `TEST_JOBS=1 bundle exec rake test:slow | grep "^==>" | sort -t"(" -k2 -rn`.
    LONGEST_SLOW_FILES = %w[
      test/metz_scan/commands/scan_json_guidance_test.rb
      test/metz_scan/commands/scan_suppression_ledger_test.rb
      rubocop-metz/test/integration/rails_aware_cops_fixture_integration_test.rb
      test/metz_scan/commands/scan_analyzer_config_suppression_test.rb
      test/metz_scan/commands/scan_analyzer_inline_suppression_test.rb
      rubocop-metz/test/cop/metz/views_deep_navigation_test.rb
      test/metz_scan/commands/scan_exit_auto_fix_test.rb
      test/metz_scan/commands/scan_config_disabled_test.rb
      test/metz_scan/commands/scan_exit_rubocop_errors_test.rb
      test/metz_scan/commands/scan_exit_auto_fix_failures_test.rb
      test/metz_scan/commands/scan_path_scoped_include_note_test.rb
      test/metz_scan/commands/scan_rails_aware_include_test.rb
      test/metz_scan/commands/scan_directory_view_templates_test.rb
      test/metz_scan/check_ci_parity_test.rb
      test/metz_scan/commands/scan_exit_templates_outside_views_test.rb
    ].freeze

    module_function

    def all_files
      files_for(ALL_PATTERNS)
    end

    def fast_files
      all_files - slow_files
    end

    def slow_files
      files_for(SLOW_PATTERNS)
    end

    def slow_files_longest_first
      LONGEST_SLOW_FILES + (slow_files - LONGEST_SLOW_FILES)
    end

    def files_for(patterns)
      patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort
    end
  end
end
