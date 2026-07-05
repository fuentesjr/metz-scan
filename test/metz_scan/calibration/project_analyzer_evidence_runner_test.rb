# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

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
    ManifestFixture = Struct.new(:cal_root, :root, :scan_paths, :manifest, keyword_init: true)

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
      project_analyzer_metadata: { "project_analyzer_category" => "state", "decision_subject_kind" => "state" },
      why_it_matters: "Repeated branching makes change ripple.",
      suggested_next_moves: ["Consolidate repeated logic."]
    )
    PACKAGE_DEPENDENCY_FINDING = FindingFixture.new(
      rule_id: "MetzProject/PackageDependencyPressure", message: "Detected shared dependency pattern.",
      report_occurrences: [OccurrenceFixture.new(path: "app/services/order_sync.rb", line: 15, context: "OrderSync")],
      project_analyzer_status: "candidate", confidence: "low", triage_severity: "shared dependency",
      triage_summary: "shared dependency candidate",
      project_analyzer_metadata: { "project_analyzer_category" => "shared_dependency",
                                   "dependency_pressure_category" => "shared_dependency" },
      why_it_matters: "Broad shared dependencies can reveal global APIs.",
      suggested_next_moves: ["Review broad API callers."]
    )
    PACKAGE_BOUNDARY_FINDING = FindingFixture.new(
      rule_id: "MetzProject/PackageDependencyPressure",
      message: "OpenFoodNetwork::ScopeVariantToHub is referenced across packages.",
      report_occurrences: [OccurrenceFixture.new(path: "app/services/scope_variant_to_hub.rb",
                                                 line: 21, context: "OpenFoodNetwork::ScopeVariantToHub")],
      project_analyzer_status: "candidate", confidence: "medium", triage_severity: "manual review",
      triage_summary: "manual package-boundary review candidate",
      project_analyzer_metadata: { "project_analyzer_category" => "package_boundary",
                                   "dependency_pressure_category" => "package_boundary",
                                   "declaration" => "OpenFoodNetwork::ScopeVariantToHub" },
      why_it_matters: "Package pressure can reveal an adapter that knows too many callers.",
      suggested_next_moves: ["Review package boundaries."]
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
          analyzer_names: [], targets_file: nil }
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
        assert_equal [active_project_index_backend], target_index_backends(summary)
        assert_sample_app_finding_count(summary)
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

      # sample_app findings require a real project index backend; without one
      # (the CI default, where optional rubydex is not installed) the real
      # analyzer path must still run end-to-end and report zero findings.
      def assert_sample_app_finding_count(summary)
        if active_project_index_backend == "null"
          assert_equal 0, summary.fetch("finding_count")
        else
          assert_predicate summary.fetch("finding_count"), :positive?
        end
      end

      def sample_app_path
        File.expand_path("../../fixtures/sample_app", __dir__)
      end

      def active_project_index_backend
        ProjectIndex.build([sample_app_path]).backend_name.to_s
      end
    end

    class ProjectAnalyzerEvidenceRunnerReadinessTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      READINESS_ASSERTIONS = %i[
        assert_package_dependency_readiness
        assert_namespace_leak_readiness
        assert_repeated_query_readiness
        assert_implicit_context_readiness
        assert_subclass_override_readiness
      ].freeze

      def test_summary_records_project_analyzer_readiness_boundaries
        with_tmpdir { |dir| assert_project_analyzer_readiness(summary_with_collaborators(dir, captures)) }
      end

      private

      def assert_project_analyzer_readiness(summary)
        readiness = summary.dig("project_analyzers", "readiness")
        READINESS_ASSERTIONS.each { |assertion| send(assertion, readiness) }
      end

      def assert_package_dependency_readiness(readiness)
        entry = readiness_entry(readiness, "MetzProject/PackageDependencyPressure")

        assert_candidate_readiness(entry)
        assert_includes entry.fetch("evidence"), "47 findings"
        assert_includes entry.fetch("next"), "Keep parked"
        assert_includes entry.fetch("not_next"), "Do not implement classifier behavior"
      end

      def assert_namespace_leak_readiness(readiness)
        entry = readiness_entry(readiness, "MetzProject/NamespaceLeakPressure")

        assert_candidate_readiness(entry)
        assert_includes entry.fetch("evidence"), "12 medium namespace-boundary prompts"
        assert_includes entry.fetch("next"), "namespace-boundary prompts"
        assert_includes entry.fetch("not_next"), "Do not implement classifier behavior"
      end

      def assert_repeated_query_readiness(readiness)
        entry = readiness_entry(readiness, "MetzProject/RepeatedQueryCriteria")

        assert_candidate_readiness(entry)
        assert_includes entry.fetch("evidence"), "16 findings"
        assert_includes entry.fetch("next"), "lifecycle lookup concepts"
        assert_includes entry.fetch("not_next"), "Do not add more query forms"
      end

      def assert_implicit_context_readiness(readiness)
        entry = readiness_entry(readiness, "MetzProject/ImplicitContextPressure")

        assert_candidate_readiness(entry)
        assert_includes entry.fetch("evidence"), "12 findings"
        assert_includes entry.fetch("next"), "Keep candidate-only"
        assert_includes entry.fetch("not_next"), "Do not add suppressions"
      end

      def assert_subclass_override_readiness(readiness)
        entry = readiness_entry(readiness, "MetzProject/SubclassOverridePressure")

        assert_candidate_readiness(entry)
        assert_includes entry.fetch("evidence"), "148 findings"
        assert_includes entry.fetch("next"), "design-pressure hook contracts"
        assert_includes entry.fetch("not_next"), "Do not implement classifier behavior"
      end

      def assert_candidate_readiness(entry)
        assert_equal "candidate", entry.fetch("status")
        assert_equal false, entry.fetch("default_output")
        assert_includes entry.fetch("disposition"), "Candidate-only"
      end

      def readiness_entry(readiness, rule_id)
        readiness.find { |entry| entry.fetch("rule_id") == rule_id }
      end
    end

    class ProjectAnalyzerEvidenceRunnerTargetManifestTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_uses_target_manifest_scan_paths
        with_tmpdir { |dir| assert_target_manifest_scan_paths(dir) }
      end

      def test_summary_rejects_missing_manifest_scan_path
        with_tmpdir { |dir| assert_missing_manifest_scan_path_is_rejected(dir) }
      end

      private

      def assert_target_manifest_scan_paths(dir)
        fixture = arrange_manifest_fixture(dir)
        call_captures = captures
        summary = summarize_manifest_fixture(fixture, call_captures)
        assert_manifest_summary(summary, fixture, call_captures)
      end

      def arrange_manifest_fixture(dir)
        root = File.join(dir, "apps", "spree")
        scan_paths = relative_manifest_scan_paths.map { |path| File.join(root, path) }
        scan_paths.each { |path| FileUtils.mkdir_p(path) }
        ManifestFixture.new(cal_root: File.join(dir, "apps"), root: root, scan_paths: scan_paths,
                            manifest: write_targets_manifest(dir, root, relative_manifest_scan_paths))
      end

      def summarize_manifest_fixture(fixture, call_captures)
        with_calibration_stubs(fixture.cal_root, call_captures, [REPEATED_BRANCHING_FINDING]) do
          ProjectAnalyzerEvidenceRunner.summarize(targets_file: fixture.manifest)
        end
      end

      def assert_manifest_summary(summary, fixture, call_captures)
        assert_equal ["spree"], target_names(summary)
        assert_equal File.expand_path(fixture.manifest), summary.fetch("targets_file")
        assert_equal expanded_scan_paths(fixture), summary.fetch("targets").first.fetch("scan_paths")
        assert_equal [expanded_scan_paths(fixture)], call_captures.fetch(:index_paths)
      end

      def target_names(summary)
        summary.fetch("targets").map { |target| target.fetch("name") }
      end

      def assert_missing_manifest_scan_path_is_rejected(dir)
        fixture = arrange_missing_manifest_fixture(dir)
        error = assert_raises(ProjectAnalyzerEvidenceRunner::Error) { summarize_manifest(fixture) }
        assert_match(/calibration scan path missing:/, error.message)
      end

      def arrange_missing_manifest_fixture(dir)
        root = File.join(dir, "apps", "spree")
        FileUtils.mkdir_p(root)
        ManifestFixture.new(manifest: write_targets_manifest(dir, root, ["spree/core/app"]))
      end

      def summarize_manifest(fixture)
        ProjectAnalyzerEvidenceRunner.summarize(targets_file: fixture.manifest)
      end

      def write_targets_manifest(dir, root, scan_paths)
        File.join(dir, "targets.yml").tap do |manifest|
          File.write(manifest, YAML.dump("targets" => [{ "root" => root, "scan_paths" => scan_paths }]))
        end
      end

      def expanded_scan_paths(fixture)
        fixture.scan_paths.map { |path| File.expand_path(path) }
      end

      def relative_manifest_scan_paths = %w[spree/core/app spree/core/lib]
    end

    class ProjectAnalyzerEvidenceRunnerCollaboratorTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      class ValidatedOptInAnalyzer
        PROJECT_ANALYZER_STATUS = "validated"

        def initialize(paths: nil, index: nil); end

        def call = [REPEATED_BRANCHING_FINDING]
      end

      def test_summary_uses_injected_internal_collaborators
        with_tmpdir { |dir| assert_injected_collaborators_used(dir) }
      end

      def test_summary_accepts_public_injected_collaborators
        with_tmpdir { |dir| assert_public_injected_collaborators_used(dir) }
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

      def test_summary_rejects_unknown_project_analyzer_before_default_target_discovery
        with_tmpdir { |dir| assert_unknown_analyzer_rejected_before_default_target_discovery(dir) }
      end

      def test_selected_default_output_keeps_analyzer_level_eligibility_gate
        findings = selected_default_output_findings([ValidatedOptInAnalyzer])

        assert_empty findings
      end

      private

      def assert_injected_collaborators_used(dir)
        FileUtils.mkdir_p(dir)
        call_captures = captures
        summary = summary_with_collaborators(dir, call_captures, default_output: true)

        assert_equal 1, summary.fetch("finding_count")
        assert_injected_collaborator_calls(summary, call_captures)
      end

      def assert_public_injected_collaborators_used(dir)
        FileUtils.mkdir_p(File.join(dir, "app"))
        call_captures = captures
        summary = public_injected_summary(dir, call_captures)

        assert_equal 1, summary.fetch("finding_count")
        assert_injected_collaborator_calls(summary, call_captures)
      end

      def public_injected_summary(dir, call_captures)
        ProjectAnalyzerEvidenceRunner.summarize(
          paths: [dir], default_output: true, index_builder: index_builder(call_captures),
          finding_runner: finding_runner(call_captures, [REPEATED_BRANCHING_FINDING])
        )
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

      def assert_unknown_analyzer_rejected_before_default_target_discovery(dir)
        error = summarize_unknown_analyzer_with_missing_default_target(dir)

        assert_match(%r{unknown project analyzer: MetzProject/MissingAnalyzer}, error.message)
      end

      def summarize_unknown_analyzer_with_missing_default_target(dir)
        with_default_apps_path(File.join(dir, "missing-default-apps")) do
          assert_raises(ProjectAnalyzerEvidenceRunner::Error) { summarize_missing_analyzer }
        end
      end

      def summarize_missing_analyzer
        ProjectAnalyzerEvidenceRunner.summarize(analyzer_names: ["MetzProject/MissingAnalyzer"])
      end

      def summarize_repeated_branching_only(dir)
        ProjectAnalyzerEvidenceRunner.summarize(paths: [dir], analyzer_names: ["MetzProject/RepeatedBranching"])
      end

      def selected_default_output_findings(analyzers)
        runner = ProjectAnalyzerEvidenceRunner::FindingRunner.new(analyzers: analyzers)

        runner.call(["app"], index: FakeIndex.new, default_output: true)
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
        assert_breakdown [["shared_dependency", 1], ["state", 1]],
                         aggregate_breakdowns.dig("metadata", "project_analyzer_category")
      end

      def assert_breakdown(expected, actual)
        assert_equal expected.map { |value, count| { "value" => value, "finding_count" => count } }, actual
      end
    end

    class ProjectAnalyzerEvidenceRunnerBaselineDeltaTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_records_baseline_deltas
        with_tmpdir { |dir| assert_baseline_deltas(dir) }
      end

      def test_summary_rejects_baseline_scope_mismatch
        with_tmpdir { |dir| assert_baseline_scope_mismatch(dir) }
      end

      private

      def assert_baseline_deltas(dir)
        summary, baseline = summary_with_baseline_deltas(dir)

        assert_baseline_delta_summary(summary, baseline)
        assert_includes ProjectAnalyzerEvidenceRunner::MarkdownRenderer.new(summary).call, "## Baseline Deltas"
      end

      def summary_with_baseline_deltas(dir)
        baseline = prepare_baseline_dir(dir)
        findings = [REPEATED_BRANCHING_FINDING, PACKAGE_DEPENDENCY_FINDING]
        [summarize_with_baseline(dir, baseline, findings), baseline]
      end

      def assert_baseline_delta_summary(summary, baseline)
        delta = summary.fetch("baseline_delta")

        assert_equal File.expand_path(baseline), delta.dig("baseline", "file")
        assert_baseline_total_deltas(delta)
        assert_baseline_breakdown_deltas(delta)
      end

      def assert_baseline_total_deltas(delta)
        assert_equal 1, delta.fetch("finding_count").fetch("delta")
        assert_equal 1, delta.fetch("offense_count").fetch("delta")
        assert_rule_delta(delta, "MetzProject/PackageDependencyPressure", findings: 1, offenses: 1)
      end

      def assert_baseline_breakdown_deltas(delta)
        assert_breakdown_delta(delta.dig("breakdowns", "confidence"), "low", 1)
        assert_breakdown_delta(delta.dig("breakdowns", "triage_severity"), "shared dependency", 1)
        assert_breakdown_delta(delta.dig("breakdowns", "metadata", "project_analyzer_category"),
                               "shared_dependency", 1)
      end

      def assert_rule_delta(delta, rule_id, findings:, offenses:)
        rule = delta.fetch("rules").find { |entry| entry.fetch("cop_name") == rule_id }

        assert_equal findings, rule.fetch("finding_count").fetch("delta")
        assert_equal offenses, rule.fetch("offense_count").fetch("delta")
      end

      def assert_breakdown_delta(entries, value, expected_delta)
        entry = entries.find { |candidate| candidate.fetch("value") == value }

        assert_equal expected_delta, entry.fetch("finding_count").fetch("delta")
      end

      def assert_baseline_scope_mismatch(dir)
        assert_match(/baseline scope mismatch for default_output/, baseline_scope_mismatch_error(dir).message)
      end

      def baseline_scope_mismatch_error(dir)
        assert_raises(ProjectAnalyzerEvidenceRunner::Error) do
          summarize_with_baseline(dir, mismatched_baseline_file(dir), [REPEATED_BRANCHING_FINDING])
        end
      end

      def summarize_with_baseline(dir, baseline, findings)
        with_calibration_stubs(dir, captures, findings) do
          ProjectAnalyzerEvidenceRunner.summarize(paths: [dir], baseline_file: baseline)
        end
      end

      def mismatched_baseline_file(dir)
        prepare_dir(dir)
        write_baseline_file(dir, baseline_summary, scope: baseline_scope.merge("default_output" => true))
      end

      def prepare_baseline_dir(dir)
        prepare_dir(dir)
        write_baseline_file(dir, baseline_summary)
      end

      def prepare_dir(dir)
        FileUtils.mkdir_p(dir)
      end

      def write_baseline_file(dir, summary, scope: baseline_scope)
        File.join(dir, "baseline.yml").tap do |path|
          File.write(path, YAML.dump("label" => "test-baseline", "scope" => scope, "summary" => summary))
        end
      end

      def baseline_scope
        { "default_output" => false, "analyzer_filter" => [], "targets_file" => nil }
      end

      def baseline_summary
        { "finding_count" => 1, "offense_count" => 1,
          "rules" => baseline_rules, "breakdowns" => baseline_breakdowns }
      end

      def baseline_rules
        [{ "cop_name" => "MetzProject/RepeatedBranching", "finding_count" => 1, "offense_count" => 1 }]
      end

      def baseline_breakdowns
        { "confidence" => [{ "value" => "medium", "finding_count" => 1 }],
          "triage_severity" => [{ "value" => "design pressure", "finding_count" => 1 }],
          "metadata" => { "project_analyzer_category" => [{ "value" => "state", "finding_count" => 1 }] } }
      end
    end

    class ProjectAnalyzerEvidenceRunnerNotableFindingsTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_summary_records_priority_notable_findings
        with_tmpdir { |dir| assert_summary_notable_findings(dir) }
      end

      def test_markdown_renders_notable_findings_section
        with_tmpdir { |dir| assert_markdown_notable_findings(dir) }
      end

      def test_markdown_renders_readiness_section
        with_tmpdir { |dir| assert_markdown_readiness(dir) }
      end

      private

      def assert_summary_notable_findings(dir)
        FileUtils.mkdir_p(dir)
        findings = [PACKAGE_DEPENDENCY_FINDING, PACKAGE_BOUNDARY_FINDING, REPEATED_BRANCHING_FINDING]
        with_calibration_stubs(dir, captures, findings) do
          ProjectAnalyzerEvidenceRunner.summarize(paths: [dir]).then { |summary| assert_notable_summary(summary) }
        end
      end

      def assert_notable_summary(summary)
        notable_findings = summary.fetch("notable_findings")

        assert_notable_count(summary, notable_findings)
        assert_notable_rule_order(notable_findings)
        assert_notable_package_boundary(notable_findings.last)
        refute_low_confidence_notable(notable_findings)
      end

      def assert_notable_count(summary, notable_findings)
        assert_equal 2, notable_findings.size
        assert_equal notable_findings, summary.fetch("targets").first.fetch("notable_findings")
      end

      def assert_notable_rule_order(notable_findings)
        assert_equal(["MetzProject/RepeatedBranching", "MetzProject/PackageDependencyPressure"],
                     notable_findings.map { |finding| finding.fetch("rule_id") })
      end

      def assert_notable_package_boundary(finding)
        assert_equal "package_boundary", finding.fetch("category")
        assert_equal "OpenFoodNetwork::ScopeVariantToHub", finding.dig("metadata", "declaration")
        assert_equal ["project_analyzer_category"], Commands::Scan::ProjectAnalyzerMetadata.category_metadata_keys
      end

      def refute_low_confidence_notable(notable_findings)
        refute_includes notable_findings.map { |finding| finding.fetch("message") },
                        PACKAGE_DEPENDENCY_FINDING.message
      end

      def assert_markdown_notable_findings(dir)
        rendered = rendered_markdown_for(dir)

        assert_includes rendered, "## Notable Findings"
        assert_includes rendered, "OpenFoodNetwork::ScopeVariantToHub is referenced across packages."
        assert_includes rendered, "package_boundary"
      end

      def assert_markdown_readiness(dir)
        rendered = rendered_markdown_for(dir)

        assert_includes rendered, "## Readiness"
        assert_includes rendered, "MetzProject/RepeatedQueryCriteria"
        assert_includes rendered, "Do not add more query forms"
      end

      def rendered_markdown_for(dir)
        FileUtils.mkdir_p(dir)
        summary = summary_with_collaborators(dir, captures, findings: [PACKAGE_BOUNDARY_FINDING])
        ProjectAnalyzerEvidenceRunner::MarkdownRenderer.new(summary).call
      end
    end

    class ProjectAnalyzerEvidenceRunnerArtifactTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_write_artifacts_persists_json_and_markdown
        with_tmpdir { |dir| assert_artifacts_written(write_empty_artifacts(dir)) }
      end

      def test_write_artifacts_round_trips_artifact_paths
        with_tmpdir { |dir| assert_artifact_paths_round_trip(write_empty_artifacts(dir)) }
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

      def assert_artifact_paths_round_trip(artifacts)
        persisted = JSON.parse(File.read(artifacts.fetch("json")))

        assert_equal artifacts, persisted.fetch("artifacts")
        assert_equal ProjectAnalyzerEvidenceRunner::MarkdownRenderer.new(persisted).call,
                     File.read(artifacts.fetch("markdown"))
      end
    end

    class ProjectAnalyzerCalibrationCommandTest < Minitest::Test
      include ProjectAnalyzerEvidenceRunnerHelpers

      def test_text_output_renders_readiness_evidence
        with_tmpdir { |dir| assert_text_output_readiness(run_calibration_text(dir)) }
      end

      def test_text_output_reports_written_artifacts
        with_tmpdir { |dir| assert_text_output_written_artifacts(run_calibration_write(dir), dir) }
      end

      def test_text_output_renders_baseline_deltas
        with_tmpdir { |dir| assert_text_output_baseline_delta(dir) }
      end

      private

      def assert_text_output_readiness(result)
        stdout, stderr, status = result
        assert_predicate status, :success?, stderr
        assert_includes stdout, "readiness:"
        assert_includes stdout, "MetzProject/RepeatedQueryCriteria"
        assert_includes stdout, "evidence=Expanded active fixtures show 16 findings"
      end

      def assert_text_output_written_artifacts(result, dir)
        stdout, stderr, status = result

        assert_predicate status, :success?, stderr
        assert_written_artifact_paths(stdout, artifact_dir(dir))
      end

      def assert_text_output_baseline_delta(dir)
        write_repeated_branching_files(dir)
        stdout, stderr, status = run_calibration_with_baseline(dir, write_zero_baseline(dir))

        assert_predicate status, :success?, stderr
        assert_text_baseline_delta_output(stdout)
      end

      def assert_text_baseline_delta_output(stdout)
        assert_includes stdout, "baseline deltas:"
        assert_includes stdout, "findings: +1"
        assert_includes stdout, "offenses: +2"
        assert_text_baseline_delta_details(stdout)
      end

      def assert_text_baseline_delta_details(stdout)
        assert_includes stdout, "MetzProject/RepeatedBranching findings=+1 offenses=+2"
        assert_includes stdout, "confidence: medium=+1"
        assert_includes stdout, "category: state=+1"
      end

      def assert_written_artifact_paths(stdout, artifact_dir)
        assert_includes stdout, "artifacts: #{artifact_dir}"
        assert_path_exists File.join(artifact_dir, "summary.json")
        assert_path_exists File.join(artifact_dir, "summary.md")
      end

      def artifact_dir(dir)
        File.join(dir, "calibration-results", "write-smoke")
      end

      def run_calibration_text(dir)
        Open3.capture3(
          RbConfig.ruby, "bin/check_project_analyzer_calibration", "--text", "--no-write",
          "--analyzer", "MetzProject/RepeatedQueryCriteria", dir
        )
      end

      def run_calibration_write(dir)
        Open3.capture3(
          RbConfig.ruby, "bin/check_project_analyzer_calibration", "--text",
          "--output-dir", File.join(dir, "calibration-results"), "--run-id", "write-smoke",
          "--analyzer", "MetzProject/RepeatedQueryCriteria", sample_app_path
        )
      end

      def run_calibration_with_baseline(dir, baseline)
        Open3.capture3(
          RbConfig.ruby, "bin/check_project_analyzer_calibration", "--text", "--no-write",
          "--baseline-file", baseline, "--analyzer", "MetzProject/RepeatedBranching", dir
        )
      end

      def write_repeated_branching_files(dir)
        2.times { |index| File.write(File.join(dir, "branching_#{index}.rb"), branching_source) }
      end

      def branching_source
        "case order.status\nwhen \"pending\"\n  nil\nwhen \"paid\"\n  nil\nend\n"
      end

      def write_zero_baseline(dir)
        File.join(dir, "zero-baseline.yml").tap do |path|
          File.write(path, YAML.dump("scope" => repeated_branching_scope,
                                     "summary" => { "finding_count" => 0, "offense_count" => 0,
                                                    "rules" => [], "breakdowns" => {} }))
        end
      end

      def repeated_branching_scope
        { "default_output" => false, "analyzer_filter" => ["MetzProject/RepeatedBranching"],
          "targets_file" => nil }
      end

      def sample_app_path
        File.expand_path("../../fixtures/sample_app", __dir__)
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
