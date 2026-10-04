# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Spec tests: `scan --project-analyzers` honors the scanned project's own
    # `MetzProject/*` config (Enabled: false, per-analyzer Exclude), the way the
    # default scan honors per-cop Exclude for `Metz/*` cops (owner-approved
    # 2026-10-03). Each test runs the CLI as a subprocess on a scratch copy of
    # test/fixtures/service_soup_app, with the controller moved to
    # app/workflows so no Metz/* cop fires and only MetzProject/ServiceSoup can
    # make the scan fail.
    module ProjectAnalyzerConfigScan
      ANALYZER = "MetzProject/ServiceSoup"
      MESSAGE = "OrdersController#create coordinates 4 distinct services; " \
                "consider a workflow object that owns the process."
      WORKFLOW = "app/workflows/order_workflow.rb"
      DISABLED = "#{ANALYZER}:\n  Enabled: false\n".freeze
      EXCLUDED = "#{ANALYZER}:\n  Exclude:\n    - app/workflows/**/*\n".freeze

      def setup
        @project = Dir.mktmpdir("metz-scan-project-analyzer-config")
        FileUtils.cp_r(File.join(repo_root, "test/fixtures/service_soup_app/."), @project)
        FileUtils.mkdir_p(File.join(@project, "app/workflows"))
        FileUtils.mv(File.join(@project, "app/controllers/orders_controller.rb"), File.join(@project, WORKFLOW))
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      private

      def write_config(body)
        File.write(File.join(@project, ".rubocop.yml"), body)
      end

      def offense_cop_names(json)
        json.fetch("files").flat_map { |file| file.fetch("offenses") }.map { |offense| offense.fetch("cop_name") }
      end

      def sarif_results(stdout)
        JSON.parse(stdout).fetch("runs").flat_map { |run| run.fetch("results") }
      end

      def excluded_record(line)
        { "cop_name" => ANALYZER, "path" => WORKFLOW, "line" => line, "column" => 1, "message" => MESSAGE,
          "suppressed_by" => "config_exclude", "reason" => nil, "reason_status" => "missing", "directive" => nil,
          "config" => { "path" => ".rubocop.yml", "line" => 3, "pattern" => "app/workflows/**/*" } }
      end

      def scan_json
        stdout, stderr, = scan("--format", "json")
        JSON.parse(stdout)
      rescue JSON::ParserError
        flunk "scan did not emit JSON (exit #{@status&.exitstatus}): #{stderr}"
      end

      def scan(*)
        stdout, stderr, @status = Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, bin_path, "scan", ".",
                                                 "--project-analyzers", *, chdir: @project)
        [stdout, stderr, @status]
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def bin_path = File.join(repo_root, "bin/metz-scan")
      def repo_root = File.expand_path("../../..", __dir__)
    end

    class ScanProjectAnalyzerConfigDisabledTest < Minitest::Test
      include ProjectAnalyzerConfigScan

      def test_baseline_without_config_reports_the_analyzer_and_fails
        json = scan_json
        assert_equal 1, @status.exitstatus
        assert_equal [ANALYZER] * 4, offense_cop_names(json)
      end

      def test_disabled_analyzer_reports_no_findings_and_exits_zero
        write_config(DISABLED)
        json = scan_json
        assert_equal [0, []], [@status.exitstatus, offense_cop_names(json)]
        refute json.fetch("summary").key?("project_analyzers"), "a disabled analyzer must not appear in the summary"
      end

      def test_disabled_analyzer_does_not_count_toward_offenses_or_compliance
        write_config(DISABLED)
        summary = scan_json.fetch("summary")
        assert_equal [0, 0, summary.fetch("inspected_file_count")],
                     [summary.fetch("offense_count"), summary.fetch("files_with_offenses"),
                      summary.fetch("clean_file_count")]
      end

      # Mirrors the default scan: a project `Enabled: false` is not a recorded
      # suppression, so the ledger stays empty (see the report for the evidence).
      def test_disabled_analyzer_is_not_listed_in_the_suppression_ledger
        write_config(DISABLED)
        assert_equal [], scan_json.fetch("suppressions")
      end

      def test_disabled_analyzer_text_output_has_no_analyzer_section_and_exits_zero
        write_config(DISABLED)
        stdout, = scan
        assert_equal 0, @status.exitstatus
        refute_includes stdout, ANALYZER
        refute_includes stdout, "Suppressed findings"
      end
    end

    class ScanProjectAnalyzerConfigExcludeTest < Minitest::Test
      include ProjectAnalyzerConfigScan

      TEXT_LEDGER = "#{WORKFLOW}:5:1 #{MESSAGE}\n    .rubocop.yml:3 Exclude \"app/workflows/**/*\", no reason".freeze

      def test_excluded_findings_are_not_offenses_and_exit_zero
        write_config(EXCLUDED)
        json = scan_json
        assert_equal [0, []], [@status.exitstatus, offense_cop_names(json)]
        assert_equal [0, 0], json.fetch("summary").values_at("offense_count", "files_with_offenses")
        refute json.fetch("summary").key?("project_analyzers"), "excluded findings must not be in the summary"
      end

      def test_excluded_findings_leave_their_file_clean
        write_config(EXCLUDED)
        summary = scan_json.fetch("summary")
        assert_equal summary.fetch("inspected_file_count"), summary.fetch("clean_file_count")
      end

      def test_excluded_findings_appear_in_the_suppression_ledger_in_the_config_exclude_shape
        write_config(EXCLUDED)
        assert_equal((5..8).map { |line| excluded_record(line) }, scan_json.fetch("suppressions"))
      end

      def test_excluded_findings_are_listed_in_the_text_ledger_and_not_as_offenses
        write_config(EXCLUDED)
        stdout, = scan
        assert_equal 0, @status.exitstatus
        assert_includes stdout, "Suppressed findings: 4, 4 without a reason"
        assert_includes stdout, TEXT_LEDGER
      end

      def test_exclude_that_matches_no_finding_leaves_the_analyzer_reporting
        write_config("#{ANALYZER}:\n  Exclude:\n    - lib/**/*\n")
        json = scan_json
        assert_equal 1, @status.exitstatus
        assert_equal [ANALYZER] * 4, offense_cop_names(json)
        assert_equal [], json.fetch("suppressions")
      end
    end

    class ScanProjectAnalyzerConfigFormatsTest < Minitest::Test
      include ProjectAnalyzerConfigScan

      def test_sarif_omits_disabled_analyzer_findings
        write_config(DISABLED)
        stdout, = scan("--format", "sarif")
        assert_equal [0, []], [@status.exitstatus, sarif_results(stdout)]
      end

      def test_sarif_omits_excluded_analyzer_findings
        write_config(EXCLUDED)
        stdout, = scan("--format", "sarif")
        assert_equal [0, []], [@status.exitstatus, sarif_results(stdout)]
      end

      def test_gh_annotations_omit_disabled_analyzer_findings
        write_config(DISABLED)
        stdout, = scan("--format", "gh-annotations")
        assert_equal 0, @status.exitstatus
        refute_includes stdout, ANALYZER
      end

      def test_gh_annotations_omit_excluded_analyzer_findings
        write_config(EXCLUDED)
        stdout, = scan("--format", "gh-annotations")
        assert_equal 0, @status.exitstatus
        refute_includes stdout, ANALYZER
      end
    end
  end
end
