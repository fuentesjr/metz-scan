# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Spec tests: the default scan honors a project's `Enabled: false` for
    # Metz/* cops (owner-approved 2026-10-03), reports the hidden findings in
    # the suppression ledger as `config_disabled` records, keeps Max*
    # thresholds fixed, and leaves --all-cops to plain RuboCop semantics.
    # Each test runs the CLI as a subprocess inside a scratch project.
    module ConfigDisabledScan
      LONG = "Metz/MethodsTooLong"
      GOD = "Metz/GodServiceClass"
      LONG_MESSAGE = "Metz/MethodsTooLong: Method has too many lines. [6/5]"
      LONG_SOURCE = <<~RUBY
        class Long
          def m
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            [a, b, c, d, e]
          end
        end
      RUBY
      GOD_SOURCE = <<~RUBY
        class ReportService
          def one; end

          def two; end

          def three; end
        end
      RUBY
      DISABLED_LONG = "#{LONG}:\n  Enabled: false\n".freeze

      def setup
        @project = Dir.mktmpdir("metz-scan-config-disabled")
        write_file("app/long.rb", LONG_SOURCE)
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      private

      def write_file(path, body)
        full_path = File.join(@project, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, body)
      end

      def cop_names(json)
        json.fetch("files").flat_map { |file| file.fetch("offenses") }.map { |offense| offense.fetch("cop_name") }
      end

      def ledger_cops(json)
        json.fetch("suppressions", []).map { |record| record["cop_name"] }
      end

      def scan_json(*)
        stdout, stderr, @status = scan("--format", "json", *)
        JSON.parse(stdout)
      rescue JSON::ParserError
        flunk "scan did not emit JSON (exit #{@status&.exitstatus}): #{stderr}"
      end

      def scan(*)
        Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, bin_path, "scan", ".", *, chdir: @project)
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def bin_path = File.join(repo_root, "bin/metz-scan")
      def repo_root = File.expand_path("../../..", __dir__)
    end

    class ScanConfigDisabledMetzCopTest < Minitest::Test
      include ConfigDisabledScan

      DISABLED_RECORD = {
        "cop_name" => LONG, "path" => "app/long.rb", "line" => 2, "column" => 3, "message" => LONG_MESSAGE,
        "suppressed_by" => "config_disabled", "reason" => nil, "reason_status" => "missing", "directive" => nil,
        "config" => { "path" => ".rubocop.yml", "line" => 2 }
      }.freeze

      def test_baseline_without_config_reports_the_cop_and_fails
        json = scan_json
        assert_equal 1, @status.exitstatus
        assert_equal [LONG], cop_names(json)
      end

      def test_disabled_cop_reports_no_offenses_and_exits_zero
        write_file(".rubocop.yml", DISABLED_LONG)
        json = scan_json
        assert_equal [0, []], [@status.exitstatus, cop_names(json)]
      end

      def test_disabled_cop_does_not_count_toward_offenses_or_compliance
        write_file(".rubocop.yml", DISABLED_LONG)
        summary = scan_json.fetch("summary")
        assert_equal [0, 0, summary.fetch("inspected_file_count")],
                     summary.values_at("offense_count", "files_with_offenses", "clean_file_count")
      end

      def test_disabled_cop_finding_appears_in_the_ledger_as_config_disabled
        write_file(".rubocop.yml", DISABLED_LONG)
        assert_equal [DISABLED_RECORD], scan_json.fetch("suppressions")
      end

      def test_disabled_cop_finding_is_listed_in_the_text_ledger
        write_file(".rubocop.yml", DISABLED_LONG)
        stdout, _stderr, @status = scan
        assert_equal 0, @status.exitstatus
        assert_includes stdout, "Suppressed findings: 1, 1 without a reason"
        assert_includes stdout, ".rubocop.yml:2 Enabled: false, no reason"
      end

      def test_disabling_one_cop_leaves_other_metz_cops_reporting
        write_file("app/report_service.rb", GOD_SOURCE)
        write_file(".rubocop.yml", DISABLED_LONG)
        json = scan_json
        assert_equal [1, [GOD]], [@status.exitstatus, cop_names(json)]
        assert_equal [LONG], ledger_cops(json)
      end

      def test_explicit_enabled_true_is_not_a_suppression
        write_file(".rubocop.yml", "#{LONG}:\n  Enabled: true\n")
        json = scan_json
        assert_equal [1, [LONG], []], [@status.exitstatus, cop_names(json), json.fetch("suppressions")]
      end

      def test_disabled_metz_department_hides_the_cop_and_credits_the_department
        write_file(".rubocop.yml", "Metz:\n  Enabled: false\n")
        json = scan_json
        assert_equal [0, []], [@status.exitstatus, cop_names(json)]
        assert_equal [DISABLED_RECORD], json.fetch("suppressions")
      end

      def test_cop_enabled_under_a_disabled_department_still_reports
        write_file(".rubocop.yml", "Metz:\n  Enabled: false\n#{LONG}:\n  Enabled: true\n")
        json = scan_json
        assert_equal [1, [LONG], []], [@status.exitstatus, cop_names(json), json.fetch("suppressions")]
      end
    end

    class ScanConfigDisabledThresholdTest < Minitest::Test
      include ConfigDisabledScan

      # Existing behavior pinned: the default scan runs stock thresholds.
      def test_project_max_public_methods_does_not_change_default_scan_results
        write_file("app/report_service.rb", GOD_SOURCE)
        write_file(".rubocop.yml", "#{GOD}:\n  MaxPublicMethods: 5\n")
        json = scan_json
        assert_equal 1, @status.exitstatus
        assert_includes cop_names(json), GOD
      end
    end

    class ScanConfigDisabledAllCopsTest < Minitest::Test
      include ConfigDisabledScan

      def test_all_cops_with_a_disabled_metz_cop_reports_no_finding_for_it
        write_file(".rubocop.yml", DISABLED_LONG)
        json = scan_json("--all-cops")
        refute_includes cop_names(json), LONG
        refute_includes ledger_cops(json), LONG
      end
    end
  end
end
