# frozen_string_literal: true

require "minitest/autorun"
require "support/test_file_groups"

module MetzScan
  class TestFileGroupsTest < Minitest::Test
    def test_fast_files_exclude_slow_files
      assert_empty TestFileGroups.fast_files & TestFileGroups.slow_files
    end

    def test_fast_files_include_analyzer_unit_tests
      assert_includes TestFileGroups.fast_files, "test/metz_scan/analyzers/repeated_branching_test.rb"
    end

    def test_slow_files_include_subprocess_and_full_scan_tests
      assert_slow_file "test/metz_scan/sigint_test.rb"
      assert_slow_file "rubocop-metz/test/integration/programmatic_invocation_test.rb"
    end

    def test_all_files_cover_fast_and_slow_files
      expected = (TestFileGroups.fast_files + TestFileGroups.slow_files).uniq.sort

      assert_equal TestFileGroups.all_files, expected
    end

    private

    def assert_slow_file(path)
      assert_includes TestFileGroups.slow_files, path
    end
  end
end
