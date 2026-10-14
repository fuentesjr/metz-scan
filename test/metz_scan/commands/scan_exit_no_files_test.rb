# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# R4: a scan that checked no files is a failure to check, not a pass.
module MetzScan
  module Commands
    class ScanExitNoFilesTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures

      def test_default_scan_of_an_empty_directory_exits_2_saying_no_files_scanned
        with_project do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "no files scanned")
        end
      end

      def test_all_cops_scan_of_an_empty_directory_exits_2_saying_no_files_scanned
        with_project do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "no files scanned")
        end
      end

      def test_default_scan_exits_2_saying_no_files_scanned_when_the_project_excludes_every_ruby_file
        with_all_files_excluded do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "no files scanned")
        end
      end

      def test_all_cops_scan_exits_2_saying_no_files_scanned_when_the_project_excludes_every_ruby_file
        with_all_files_excluded do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "no files scanned")
        end
      end

      private

      def with_all_files_excluded(&)
        with_project("excluded/a.rb" => CLEAN_RUBY, ".rubocop.yml" => EXCLUDE_EVERYTHING_CONFIG, &)
      end
    end
  end
end
