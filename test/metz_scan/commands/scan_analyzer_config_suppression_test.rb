# frozen_string_literal: true

require_relative "../../support/analyzer_suppression"

module MetzScan
  # Owner's Hybrid contract: config-only MetzProject entries are accepted by
  # RuboCop; analyzer suppression is applied by the wrapper, with ledger credit.
  module AnalyzerConfigSuppressionContract
    include AnalyzerSuppressionProcess
    include AnalyzerSuppressionAssertions

    def test_both_ast_analyzers_are_reported_without_suppressions
      write_branches
      report = scan_report
      assert_live(report, ([SERVICE] * 3) + ([BRANCH] * 2))
      assert_equal [], report.fetch("suppressions", [])
    end

    def test_disabled_analyzer_is_credited_without_hiding_another_rule
      write_branches
      write_config("#{SERVICE}:\n  # workflow is deliberately explicit\n  Enabled: false\n")
      assert_suppressed(scan_report, disabled_service_records, [BRANCH] * 2)
    end

    def test_disabled_analyzer_without_a_reason_leaves_no_live_findings
      write_config("#{SERVICE}:\n  Enabled: false\n")
      report = scan_report
      assert_suppressed(report, service_records(5..7, "config_disabled", config: config_location(2)), [])
    end

    def test_disabling_repeated_branching_keeps_service_soup_live
      write_branches
      write_config("#{BRANCH}:\n  Enabled: false\n")
      assert_suppressed(scan_report, disabled_branch_records, [SERVICE] * 3)
    end

    def test_exclude_credits_only_the_matching_repeated_branching_occurrence
      write_branches
      write_config("#{BRANCH}:\n  Exclude:\n    # frozen branch table\n    - app/branches/a*\n")
      assert_suppressed(scan_report, [excluded_branch_record], ([SERVICE] * 3) + [BRANCH])
    end

    def test_exclude_without_a_reason_hides_all_service_occurrences
      write_config("#{SERVICE}:\n  Exclude:\n    - app/workflows/**/*\n")
      expected = service_records(5..7, "config_exclude",
                                 config: config_location(3, "pattern" => "app/workflows/**/*"))
      assert_suppressed(scan_report, expected, [])
    end

    def test_nonmatching_exclude_preserves_findings_and_an_empty_ledger
      write_config("#{SERVICE}:\n  Exclude: [lib/**/*]\n")
      report = scan_report
      assert_live(report, [SERVICE] * 3)
      assert_equal [], report.fetch("suppressions", [])
    end

    private

    def disabled_service_records
      service_records(5..7, "config_disabled", reason: "workflow is deliberately explicit", config: config_location(3))
    end

    def excluded_branch_record
      record(BRANCH, "app/branches/a.rb", 3, kind: "config_exclude", reason: "frozen branch table",
                                             config: config_location(4, "pattern" => "app/branches/a*"))
    end

    def disabled_branch_records
      %w[a b].map do |name|
        record(BRANCH, "app/branches/#{name}.rb", 3, kind: "config_disabled", config: config_location(2))
      end
    end
  end

  class ScanAnalyzerConfigSuppressionTest < Minitest::Test
    include AnalyzerConfigSuppressionContract
  end

  class ScanAllCopsAnalyzerConfigSuppressionTest < Minitest::Test
    include AnalyzerConfigSuppressionContract

    private

    def scan_flags = ["--all-cops"]
  end

  class AnalyzerConfigRuboCopCompatibilityTest < Minitest::Test
    include AnalyzerSuppressionProcess

    def test_plain_rubocop_accepts_every_analyzer_disabled_key
      write_config(RULES.map { |rule| "#{rule}:\n  Enabled: false\n" }.join)
      rubocop(".", "--format", "json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal 0, JSON.parse(@stdout).fetch("summary").fetch("offense_count")
    end

    def test_plain_rubocop_accepts_every_analyzer_exclude_key
      write_config(RULES.map { |rule| "#{rule}:\n  Exclude: [app/**/*]\n" }.join)
      rubocop(".", "--format", "json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal 0, JSON.parse(@stdout).fetch("summary").fetch("offense_count")
    end

    def test_all_cops_accepts_every_analyzer_disabled_key
      write_config(RULES.map { |rule| "#{rule}:\n  Enabled: false\n" }.join)
      cli("scan", ".", "--all-cops", "--format", "json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal 0, JSON.parse(@stdout).fetch("summary").fetch("offense_count")
    end

    def test_all_cops_accepts_every_analyzer_exclude_key
      write_config(RULES.map { |rule| "#{rule}:\n  Exclude: [app/**/*]\n" }.join)
      cli("scan", ".", "--all-cops", "--format", "json")
      assert_equal 0, @status.exitstatus, @stderr
      assert_equal 0, JSON.parse(@stdout).fetch("summary").fetch("offense_count")
    end

    def test_analyzer_config_entries_do_not_register_rubocop_cop_classes
      write_config(RULES.map { |rule| "#{rule}:\n  Enabled: true\n" }.join)
      rubocop("--show-cops", "MetzProject/*")
      assert_equal 0, @status.exitstatus, @stderr
      assert_empty @stdout
    end
  end
end
