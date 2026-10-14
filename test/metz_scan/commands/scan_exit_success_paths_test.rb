# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Guards for the paths the exit-2 changes must not disturb: a clean scan still exits 0 and
# a scan that only reports findings still exits 1. These pass before the change by design.
module MetzScan
  module Commands
    class ScanExitSuccessPathsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      # R6: RuboCop prints its pending-cops notice on stderr of clean runs; that notice is not an error.
      def test_a_clean_default_scan_still_exits_zero
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          assert_clean_scan(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      # R6
      def test_a_clean_all_cops_scan_still_exits_zero
        with_project("a.rb" => CLEAN_RUBY_FOR_STOCK_COPS) do |dir|
          assert_clean_scan(scan_subprocess(dir, ".", "--all-cops", "--format", "json"))
        end
      end

      def test_a_scan_that_only_finds_offenses_still_exits_one
        with_project("many_params.rb" => TOO_MANY_PARAMETERS) do |dir|
          result = scan_subprocess(dir, ".", "--format", "json")

          assert_equal 1, result.exitstatus, failure_context(result)
          assert_equal ["Metz/MethodsTooManyParameters"], result.json.fetch("summary").fetch("offenses_by_cop").keys
        end
      end

      private

      def assert_clean_scan(result)
        assert_equal 0, result.exitstatus, failure_context(result)
        assert_equal 1, result.json.fetch("summary").fetch("inspected_file_count")
      end
    end
  end
end
