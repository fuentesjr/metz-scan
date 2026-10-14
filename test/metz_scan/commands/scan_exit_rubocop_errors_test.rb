# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Exit status contract for `scan` (owner-approved 2026-10-13): exit 1 means only
# "findings reported". RuboCop errors on any file or config exit 2 in both modes,
# and errors take precedence over findings.
module MetzScan
  module Commands
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
