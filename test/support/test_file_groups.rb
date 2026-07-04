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
      "test/metz_scan/check_dogfood_test.rb",
      "test/metz_scan/check_published_gem_test.rb",
      "test/metz_scan/check_project_analyzer_calibration_lockfile_test.rb",
      "test/metz_scan/check_read_only_commands_test.rb",
      "test/metz_scan/check_rubydex_drift_test.rb",
      "test/metz_scan/check_tracker_queue_test.rb",
      "test/metz_scan/sigint_test.rb",
      "test/metz_scan/commands/scan_auto_fix*_test.rb",
      "test/metz_scan/commands/scan_error_test.rb",
      "test/metz_scan/commands/scan_github_annotations_format_test.rb",
      "test/metz_scan/commands/scan_project_analyzers_test.rb",
      "test/metz_scan/commands/scan_test.rb"
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

    def files_for(patterns)
      patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq.sort
    end
  end
end
