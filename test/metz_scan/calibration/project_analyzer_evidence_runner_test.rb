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
      triage_summary: "design pressure candidate",
      project_analyzer_metadata: { "decision_subject_kind" => "state" },
      why_it_matters: "Repeated branching makes change ripple.",
      suggested_next_moves: ["Consolidate repeated logic."]
    )
    PACKAGE_DEPENDENCY_FINDING = FindingFixture.new(
      rule_id: "MetzProject/PackageDependencyPressure", message: "Detected candidate pattern.",
      report_occurrences: [OccurrenceFixture.new(path: "app/services/order_sync.rb", line: 15, context: "OrderSync")],
      project_analyzer_status: "candidate", confidence: "low", triage_severity: "shared dependency",
      triage_summary: "shared dependency candidate",
      project_analyzer_metadata: { "dependency_pressure_category" => "shared_dependency" },
      why_it_matters: "Broad shared dependencies can reveal global APIs.",
      suggested_next_moves: ["Review broad API callers."]
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

      def summary_with_collaborators(dir, call_captures, findings: [REPEATED_BRANCHING_FINDING],
                                     default_output: false)
        target_set = ProjectAnalyzerEvidenceRunner::TargetSet.new(paths: [dir], default_apps_path: dir)
        ProjectAnalyzerEvidenceRunner::Summary.new(
          base_summary_options(target_set, dir, default_output).merge(collaborator_options(call_captures, findings))
        ).to_h
      end

      def base_summary_options(target_set, dir, default_output)
        { targets: target_set.paths, target_set: target_set, default_output: default_output, fixture_root: dir,
          analyzer_names: [] }
      end

      def collaborator_options(call_captures, findings)
        { index_builder: index_builder(call_captures), finding_runner: finding_runner(call_captures, findings) }
      end

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
          %w[chatwoot/app chatwoot/lib decidim/lib spree/spree/core].each do |path|
            FileUtils.mkdir_p(File.join(root, path))
          end
        end
      end

      def run_default_summary(cal_root)
        call_captures = captures
        with_calibration_stubs(cal_root, call_captures, [REPEATED_BRANCHING_FINDING]) do
          [ProjectAnalyzerEvidenceRunner.summarize, call_captures]
        end
      end

      def assert_default_summary(summary, call_captures)
        assert_equal %w[chatwoot decidim spree], target_names(summary)
        assert_equal [%w[app lib], %w[lib], []], target_scan_paths(summary)
        assert_summary_counts(summary)
        assert_default_runner_calls(call_captures)
        assert_skipped_target(summary.fetch("targets").last)
      end

      def assert_default_runner_calls(call_captures)
        assert_equal false, call_captures.fetch(:runner_calls).first.fetch(:default_output)
        assert_equal 2, call_captures.fetch(:runner_calls).size
      end

      def assert_summary_counts(summary)
        assert_equal 2, summary.fetch("finding_count")
        assert_equal 2, summary.dig("project_analyzers", "finding_count")
        assert_equal "fake", summary.fetch("targets").first.dig("index", "backend")
      end

      def assert_skipped_target(target)
        assert_empty target.fetch("scan_paths")
        assert_equal "none", target.dig("index", "backend")
        assert_match(%r{no top-level app/ or lib}, target.dig("index", "reason"))
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

    class ProjectAnalyzerEvidenceRunnerCollaboratorTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_uses_injected_internal_collaborators
        with_tmpdir { |dir| assert_injected_collaborators_used(dir) }
      end

      def test_summary_restricts_project_analyzers_by_rule_id
        with_tmpdir { |dir| assert_analyzer_filter_forwarded(dir) }
      end

      def test_summary_rejects_unknown_project_analyzer
        error = assert_raises(ProjectAnalyzerEvidenceRunner::Error) do
          ProjectAnalyzerEvidenceRunner.summarize(analyzer_names: ["MetzProject/MissingAnalyzer"])
        end

        assert_match(%r{unknown project analyzer: MetzProject/MissingAnalyzer}, error.message)
      end

      private

      def assert_injected_collaborators_used(dir)
        FileUtils.mkdir_p(dir)
        call_captures = captures
        summary = summary_with_collaborators(dir, call_captures, default_output: true)

        assert_equal 1, summary.fetch("finding_count")
        assert_injected_collaborator_calls(summary, call_captures)
      end

      def assert_injected_collaborator_calls(summary, call_captures)
        assert_equal [summary.fetch("targets").first.fetch("scan_paths")], call_captures.fetch(:index_paths)
        assert_equal true, call_captures.fetch(:runner_calls).first.fetch(:default_output)
      end

      def assert_analyzer_filter_forwarded(dir)
        write_filtered_analyzer_fixture(dir)
        summary = summarize_repeated_branching_only(dir)

        assert_equal ["MetzProject/RepeatedBranching"], summary_rule_ids(summary)
        assert_equal ["MetzProject/RepeatedBranching"], cop_breakdown_values(summary)
      end

      def summarize_repeated_branching_only(dir)
        ProjectAnalyzerEvidenceRunner.summarize(paths: [dir], analyzer_names: ["MetzProject/RepeatedBranching"])
      end

      def write_filtered_analyzer_fixture(dir)
        write_file(dir, "branching_one.rb", branching_source)
        write_file(dir, "branching_two.rb", branching_source)
        write_file(dir, "service_soup.rb", service_soup_source)
      end

      def write_file(dir, name, source)
        File.write(File.join(dir, name), source)
      end

      def branching_source
        "case order.status\nwhen \"pending\"\n  nil\nwhen \"paid\"\n  nil\nend\n"
      end

      def service_soup_source
        "ValidateOrder.call(order)\nReserveInventory.call(order)\nCapturePayment.call(order)\n"
      end

      def summary_rule_ids(summary)
        summary.dig("project_analyzers", "rules").map { |rule| rule.fetch("cop_name") }
      end

      def cop_breakdown_values(summary)
        summary.dig("breakdowns", "cop_name").map { |row| row["value"] }
      end
    end

    class ProjectAnalyzerEvidenceRunnerBreakdownTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_records_breakdowns_for_triage_and_analyzer_metadata
        with_tmpdir { |dir| assert_summary_breakdowns(dir) }
      end

      private

      def assert_summary_breakdowns(dir)
        FileUtils.mkdir_p(dir)
        findings = [REPEATED_BRANCHING_FINDING, PACKAGE_DEPENDENCY_FINDING]
        with_calibration_stubs(dir, captures, findings) do
          ProjectAnalyzerEvidenceRunner.summarize(paths: [dir]).then { |summary| assert_breakdown_summary(summary) }
        end
      end

      def assert_breakdown_summary(summary)
        aggregate_breakdowns = summary.fetch("breakdowns")

        assert_equal aggregate_breakdowns, summary.fetch("targets").first.fetch("breakdowns")
        assert_basic_breakdowns(aggregate_breakdowns)
        assert_metadata_breakdowns(aggregate_breakdowns)
      end

      def assert_basic_breakdowns(aggregate_breakdowns)
        assert_breakdown [["MetzProject/PackageDependencyPressure", 1],
                          ["MetzProject/RepeatedBranching", 1]], aggregate_breakdowns.fetch("cop_name")
        assert_breakdown [["low", 1], ["medium", 1]], aggregate_breakdowns.fetch("confidence")
        assert_breakdown [["design pressure", 1], ["shared dependency", 1]],
                         aggregate_breakdowns.fetch("triage_severity")
      end

      def assert_metadata_breakdowns(aggregate_breakdowns)
        assert_breakdown [["state", 1]], aggregate_breakdowns.dig("metadata", "decision_subject_kind")
        assert_breakdown [["shared_dependency", 1]],
                         aggregate_breakdowns.dig("metadata", "dependency_pressure_category")
      end

      def assert_breakdown(expected, actual)
        assert_equal expected.map { |value, count| { "value" => value, "finding_count" => count } }, actual
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
