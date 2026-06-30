# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/calibration/project_analyzer_evidence_runner"

module MetzScan
  module Calibration
    FindingFixture = Struct.new(
      :rule_id, :message, :report_occurrences, :project_analyzer_status,
      :confidence, :triage_severity, :triage_summary, :project_analyzer_metadata,
      :why_it_matters, :suggested_next_moves, keyword_init: true
    )
    OccurrenceFixture = Struct.new(:path, :line, :context, keyword_init: true) do
      def line_source = "source"

      def report_line = line
    end

    EMPTY_TARGET = {
      "name" => "empty", "root" => "/tmp/project-analyzer-calibration/apps/empty",
      "scan_paths" => ["/tmp/project-analyzer-calibration/apps/empty/app"],
      "git" => {}, "index" => { "backend" => "null" }, "project_analyzers" => {},
      "finding_count" => 0, "offense_count" => 0
    }.freeze
    EMPTY_SUMMARY = {
      "generated_at" => "2026-06-30T00:00:00Z", "default_output" => false,
      "fixture_root" => "/tmp/project-analyzer-calibration/apps", "targets" => [EMPTY_TARGET],
      "project_analyzers" => { "rules" => [] }, "finding_count" => 0, "offense_count" => 0
    }.freeze
    REPEATED_BRANCHING_FINDING = FindingFixture.new(
      rule_id: "MetzProject/RepeatedBranching", message: "Detected candidate pattern.",
      report_occurrences: [OccurrenceFixture.new(path: "app/models/order.rb", line: 10, context: "Order")],
      project_analyzer_status: "validated", confidence: "medium", triage_severity: "design pressure",
      triage_summary: "design pressure candidate", project_analyzer_metadata: {},
      why_it_matters: "Repeated branching makes change ripple.",
      suggested_next_moves: ["Consolidate repeated logic."]
    )

    module ProjectAnalyzerEvidenceRunnerHelpers
      def with_tmpdir(&)
        Dir.mktmpdir("metz-scan-calibration-evidence-runner-test", &)
      end

      def with_calibration_stubs(cal_root, captures, findings, &block)
        with_default_apps_path(cal_root) do
          with_fake_index(captures) { with_fake_runner(captures, findings, &block) }
        end
      end

      def with_default_apps_path(cal_root, &)
        with_singleton_method(ProjectAnalyzerEvidenceRunner, :default_apps_path, -> { cal_root }, &)
      end

      def with_fake_index(captures, &)
        with_singleton_method(ProjectIndex, :build, index_builder(captures), &)
      end

      def with_fake_runner(captures, findings, &)
        with_singleton_method(Commands::Scan::ProjectAnalyzerRunner, :project_findings_for,
                              finding_runner(captures, findings), &)
      end

      def index_builder(captures)
        lambda do |paths|
          captures.fetch(:index_paths) << paths
          FakeIndex.new
        end
      end

      def finding_runner(captures, findings)
        lambda do |paths, index:, default_output:|
          captures.fetch(:runner_calls) << { paths: paths, index: index, default_output: default_output }
          findings
        end
      end

      def captures = { index_paths: [], runner_calls: [] }

      def with_singleton_method(target, name, replacement)
        singleton = singleton_class_for(target)
        original = replace_singleton_method(singleton, name, replacement)
        yield
      ensure
        restore_singleton_method(singleton, name, original)
      end

      def singleton_class_for(target)
        class << target; self; end
      end

      def replace_singleton_method(singleton, name, replacement)
        singleton.instance_method(name).tap { singleton.send(:define_method, name, replacement) }
      end

      def restore_singleton_method(singleton, name, original)
        singleton.send(:define_method, name, original)
      end
    end

    class ProjectAnalyzerEvidenceRunnerSummaryTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_discovers_default_app_targets_and_records_metadata
        with_tmpdir { |dir| assert_default_summary_for(dir) }
      end

      def test_summary_rejects_missing_targets
        with_tmpdir { |dir| assert_missing_target_is_rejected(dir) }
      end

      def test_summary_forwards_default_output_flag_to_project_analyzer_runner
        with_tmpdir { |dir| assert_default_output_forwarded(dir) }
      end

      def test_summary_runs_real_project_analyzer_path_against_fixture
        summary = ProjectAnalyzerEvidenceRunner.summarize(paths: [sample_app_path])

        assert_equal ["sample_app"], target_names(summary)
        assert_equal ["rubydex"], target_index_backends(summary)
        assert summary.fetch("finding_count").positive?
      end

      private

      def assert_default_summary_for(dir)
        cal_root = arrange_default_apps(dir)
        run_default_summary(cal_root).then { |summary, call_captures| assert_default_summary(summary, call_captures) }
      end

      def arrange_default_apps(dir)
        File.join(dir, ProjectAnalyzerEvidenceRunner::DEFAULT_APPS_PATH).tap do |root|
          %w[chatwoot/app chatwoot/lib decidim/lib].each { |path| FileUtils.mkdir_p(File.join(root, path)) }
        end
      end

      def run_default_summary(cal_root)
        call_captures = captures
        with_calibration_stubs(cal_root, call_captures, [REPEATED_BRANCHING_FINDING]) do
          [ProjectAnalyzerEvidenceRunner.summarize, call_captures]
        end
      end

      def assert_default_summary(summary, call_captures)
        assert_equal %w[chatwoot decidim], target_names(summary)
        assert_equal [%w[app lib], %w[lib]], target_scan_paths(summary)
        assert_summary_counts(summary)
        assert_equal false, call_captures.fetch(:runner_calls).first.fetch(:default_output)
      end

      def assert_summary_counts(summary)
        assert_equal 2, summary.fetch("finding_count")
        assert_equal 2, summary.dig("project_analyzers", "finding_count")
        assert_equal "fake", summary.fetch("targets").first.dig("index", "backend")
      end

      def target_names(summary) = summary.fetch("targets").map { |target| target.fetch("name") }

      def target_scan_paths(summary) = summary.fetch("targets").map { |target| relative_scan_paths(target) }

      def target_index_backends(summary) = summary.fetch("targets").map { |target| target.dig("index", "backend") }

      def relative_scan_paths(target)
        target.fetch("scan_paths").map { |path| File.basename(path) }
      end

      def assert_missing_target_is_rejected(dir)
        error = assert_raises(ProjectAnalyzerEvidenceRunner::Error) { summarize_missing_target(dir) }
        assert_match(/calibration target missing:/, error.message)
      end

      def summarize_missing_target(dir)
        ProjectAnalyzerEvidenceRunner.summarize(paths: [File.join(dir, "missing")])
      end

      def assert_default_output_forwarded(dir)
        FileUtils.mkdir_p(dir)
        call_captures = captures
        with_calibration_stubs(dir, call_captures, []) { summarize_default_output(dir) }
        assert_equal true, call_captures.fetch(:runner_calls).first.fetch(:default_output)
      end

      def summarize_default_output(dir)
        ProjectAnalyzerEvidenceRunner.summarize(paths: [dir], default_output: true)
      end

      def sample_app_path
        File.expand_path("../../fixtures/sample_app", __dir__)
      end
    end

    class ProjectAnalyzerEvidenceRunnerArtifactTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_write_artifacts_persists_json_and_markdown
        with_tmpdir { |dir| assert_artifacts_written(write_empty_artifacts(dir)) }
      end

      private

      def write_empty_artifacts(dir)
        ProjectAnalyzerEvidenceRunner.write_artifacts(EMPTY_SUMMARY, output_dir: dir, run_id: "run")
      end

      def assert_artifacts_written(artifacts)
        assert_path_exists artifacts.fetch("json")
        assert_path_exists artifacts.fetch("markdown")
        assert_includes File.read(artifacts.fetch("json")), %("artifacts")
        assert_includes File.read(artifacts.fetch("markdown")), "Project analyzer evidence"
      end
    end

    class FakeIndex
      def backend_name = :fake

      def available? = true

      def reason = nil

      def indexed_files = ["app/models/order.rb"]

      def index_errors = []

      def diagnostics = []
    end
  end
end
