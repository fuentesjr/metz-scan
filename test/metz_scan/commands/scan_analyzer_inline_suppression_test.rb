# frozen_string_literal: true

require_relative "../../support/analyzer_suppression"

module MetzScan
  module AnalyzerInlineSuppressionContract
    include AnalyzerSuppressionProcess
    include AnalyzerSuppressionAssertions

    def test_same_line_directives_record_reasons_and_do_not_disable_later_lines
      write_file(WORKFLOW, same_line_source)
      assert_suppressed(scan_report, same_line_records, [SERVICE])
    end

    def test_block_disable_hides_findings_and_credits_its_opening_line
      write_file(WORKFLOW, "# metz-scan:disable #{SERVICE} -- vendor workflow\n#{SERVICE_SOURCE}" \
                           "# metz-scan:enable #{SERVICE}\n")
      expected = service_records(6..8, "inline_disable", reason: "vendor workflow", directive: { "line" => 1 })
      assert_suppressed(scan_report, expected, [])
    end

    def test_block_enable_restores_reporting_after_the_closed_range
      write_file(WORKFLOW, closed_block_source)
      expected = record(SERVICE, WORKFLOW, 6, kind: "inline_disable", reason: "first step", directive: { "line" => 5 })
      assert_suppressed(scan_report, [expected], [SERVICE] * 2)
    end

    def test_block_without_a_reason_suppresses_only_its_named_rule
      write_disabled_branches
      expected = %w[a b].map do |name|
        record(BRANCH, "app/branches/#{name}.rb", 4, kind: "inline_disable", directive: { "line" => 1 })
      end
      assert_suppressed(scan_report, expected, [SERVICE] * 3)
    end

    def test_same_line_repeated_branching_disable_preserves_the_other_file
      write_branches
      write_file("app/branches/a.rb", inline_branch_source)
      assert_suppressed(scan_report, [inline_branch_record], ([SERVICE] * 3) + [BRANCH])
    end

    def test_rubocop_analyzer_disable_remains_unsupported
      write_file(WORKFLOW, "# rubocop:disable #{SERVICE}\n#{SERVICE_SOURCE}# rubocop:enable #{SERVICE}\n")
      report = scan_report
      assert_live(report, [SERVICE] * 3)
      assert_equal [], report.fetch("suppressions", [])
    end

    private

    def same_line_records
      [record(SERVICE, WORKFLOW, 5, kind: "inline_disable", reason: "vendor workflow", directive: { "line" => 5 }),
       record(SERVICE, WORKFLOW, 6, kind: "inline_disable", directive: { "line" => 6 })]
    end

    def same_line_source
      source = SERVICE_SOURCE.sub("ValidateOrder.call(order)",
                                  "ValidateOrder.call(order) # metz-scan:disable #{SERVICE} -- vendor workflow")
      source.sub("ReserveInventory.call(order)", "ReserveInventory.call(order) # metz-scan:disable #{SERVICE}")
    end

    def closed_block_source
      source = SERVICE_SOURCE.sub("    ValidateOrder",
                                  "    # metz-scan:disable #{SERVICE} -- first step\n    ValidateOrder")
      source.sub("    ReserveInventory", "    # metz-scan:enable #{SERVICE}\n    ReserveInventory")
    end

    def write_disabled_branches
      %w[a b].each do |name|
        write_file("app/branches/#{name}.rb", "# metz-scan:disable #{BRANCH}\n#{BRANCH_SOURCE}" \
                                              "# metz-scan:enable #{BRANCH}\n")
      end
    end

    def inline_branch_source
      BRANCH_SOURCE.sub("case order.status", "case order.status # metz-scan:disable #{BRANCH} -- legacy table")
    end

    def inline_branch_record
      record(BRANCH, "app/branches/a.rb", 3, kind: "inline_disable", reason: "legacy table", directive: { "line" => 3 })
    end
  end

  class ScanAnalyzerInlineSuppressionTest < Minitest::Test
    include AnalyzerInlineSuppressionContract
  end

  class ScanAllCopsAnalyzerInlineSuppressionTest < Minitest::Test
    include AnalyzerInlineSuppressionContract

    private

    def scan_flags = ["--all-cops"]
  end

  class AnalyzerSuppressionCatalogCompatibilityTest < Minitest::Test
    include AnalyzerSuppressionProcess
    include AnalyzerSuppressionAssertions

    METZ_COPS = %w[
      Metz/ClassesTooLong Metz/ControllersTooManyDirectCollaborators Metz/DemeterTrainWreck Metz/GodServiceClass
      Metz/MethodsTooLong Metz/MethodsTooManyParameters Metz/OperationsTooManyPublicMethods Metz/TestAssertsOnInternals
      Metz/TestReachesPrivate Metz/TestStubsSubject Metz/ViewsDeepNavigation
    ].freeze

    def test_custom_directives_are_ordinary_comments_to_plain_rubocop
      write_config("Lint/CopDirectiveSyntax:\n  Enabled: true\nLint/RedundantCopDisableDirective:\n  Enabled: true\n")
      write_file(WORKFLOW, custom_comments_source)
      rubocop(".", "--format", "json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal([], JSON.parse(@stdout).fetch("files").flat_map { |file| file.fetch("offenses") })
    end

    def test_rules_json_contains_only_the_existing_metz_cops
      cli("rules", "--json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal METZ_COPS.sort, JSON.parse(@stdout).map { |entry| entry.fetch("name") }.sort
    end

    def test_explain_still_rejects_analyzer_rule_ids
      cli("explain", SERVICE)
      assert_equal 64, @status.exitstatus
      assert_empty @stdout
      assert_includes @stderr, SERVICE
    end

    def test_guidance_uses_analyzer_metadata_and_contains_only_reported_rules
      report = scan_report
      assert_equal [SERVICE], report.fetch("guidance").keys
      assert_equal service_guidance, report.fetch("guidance").fetch(SERVICE)
    end

    def test_explicit_enabled_analyzer_entries_leave_json_guidance_unchanged
      write_branches
      baseline = scan_report.fetch("guidance")
      write_config(RULES.map { |rule| "#{rule}:\n  Enabled: true\n" }.join)
      assert_equal baseline, scan_report.fetch("guidance")
    end

    private

    def custom_comments_source
      source = SERVICE_SOURCE.sub("ValidateOrder.call(order)",
                                  "ValidateOrder.call(order) # metz-scan:disable #{SERVICE}")
      "# metz-scan:disable #{SERVICE} -- workflow\n#{source}" \
        "# metz-scan:enable #{SERVICE}\n# metz-scan:disable #{BRANCH}\n"
    end

    def service_guidance
      { "why_it_matters" => "Service-object soup scatters one workflow across many procedural steps " \
                            "and makes orchestration harder to change.", "fix_safety" => "manual",
        "suggested_next_moves" => ["Introduce a workflow object that owns the multi-step process.",
                                   "Keep the controller or job action at one high-level command when possible."] }
    end
  end
end
