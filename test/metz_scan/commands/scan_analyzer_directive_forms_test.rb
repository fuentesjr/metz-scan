# frozen_string_literal: true

require_relative "../../support/analyzer_suppression"

module MetzScan
  # Only `# metz-scan:disable MetzProject/<Rule>`, on the reported line or as a
  # block closed by a `# metz-scan:enable` naming the rule, hides an analyzer
  # finding. RuboCop's other directive modes and `all` do not reach analyzers.
  class ScanAnalyzerDirectiveFormsTest < Minitest::Test
    include AnalyzerSuppressionProcess
    include AnalyzerSuppressionAssertions

    def test_todo_does_not_suppress_an_analyzer_finding
      write_file(WORKFLOW, trailing_directive("# metz-scan:todo #{SERVICE}"))
      assert_unsuppressed
    end

    def test_disable_next_does_not_suppress_an_analyzer_finding
      write_file(WORKFLOW, SERVICE_SOURCE.sub("    ValidateOrder",
                                              "    # metz-scan:disable-next #{SERVICE}\n    ValidateOrder"))
      assert_unsuppressed
    end

    def test_disable_all_does_not_suppress_an_analyzer_finding
      write_file(WORKFLOW, trailing_directive("# metz-scan:disable all"))
      assert_unsuppressed
    end

    def test_enable_all_does_not_close_an_analyzer_block
      source = SERVICE_SOURCE.sub("    ReserveInventory", "    # metz-scan:enable all\n    ReserveInventory")
      write_file(WORKFLOW, "# metz-scan:disable #{SERVICE} -- vendor workflow\n#{source}")
      expected = service_records([6, 8, 9], "inline_disable", reason: "vendor workflow", directive: { "line" => 1 })
      assert_suppressed(scan_report, expected, [])
    end

    private

    def trailing_directive(directive)
      SERVICE_SOURCE.sub("ValidateOrder.call(order)", "ValidateOrder.call(order) #{directive}")
    end

    def assert_unsuppressed
      report = scan_report
      assert_live(report, [SERVICE] * 3)
      assert_equal [], report.fetch("suppressions", [])
    end
  end
end
