# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerTriageTest < Minitest::Test
      BRANCHING_SOURCE = "case order.status\nwhen \"pending\"\n  nil\nwhen \"paid\", \"cancelled\"\n  nil\nend\n"
      SERVICE_SOURCE = <<~RUBY
        class OrdersController
          def create
            ValidateOrder.call(order)
            ReserveInventory.call(order)
            CapturePayment.new(order).call
          end
        end
      RUBY
      REPEATED_BRANCHING_SUMMARY = {
        "cop_name" => "MetzProject/RepeatedBranching", "status" => "validated",
        "confidence" => "medium", "triage_severity" => "design pressure",
        "finding_count" => 1, "offense_count" => 2
      }.freeze

      def setup
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzer-triage-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_project_analyzer_offenses_include_triage_metadata
        assert_service_soup_triage_metadata
        assert_match(/workflow/i, service_soup_metadata.fetch("triage_summary"))
        assert_equal "refactor", service_soup_offense.fetch("severity")
      end

      def test_project_analyzer_summary_counts_findings_and_expanded_offenses
        assert_equal 1, repeated_branching_summary.fetch("finding_count")
        assert_equal 2, repeated_branching_summary.fetch("offense_count")
        assert_repeated_branching_rule_summary
      end

      def test_repeated_branching_offenses_preserve_decision_subject_metadata
        metadata = repeated_branching_offense.fetch("project_analyzer")

        assert_equal "state", metadata.fetch("decision_subject_kind")
        assert_equal "state branch subject", metadata.fetch("decision_subject_label")
        assert_includes repeated_branching_offense.fetch("message"), "order.status (state branch subject) branches"
      end

      private

      def assert_service_soup_triage_metadata
        expected = { "status" => "validated", "confidence" => "medium", "triage_severity" => "design pressure" }
        assert_equal expected, service_soup_metadata.slice(*expected.keys)
      end

      def service_soup_metadata
        service_soup_offense.fetch("project_analyzer")
      end

      def service_soup_offense
        offenses(merged_service_soup).find { |offense| offense.fetch("cop_name") == "MetzProject/ServiceSoup" }
      end

      def repeated_branching_summary
        merged_repeated_branching.dig("summary", "project_analyzers")
      end

      def repeated_branching_offense
        offenses(merged_repeated_branching).find do |offense|
          offense.fetch("cop_name") == "MetzProject/RepeatedBranching"
        end
      end

      def assert_repeated_branching_rule_summary
        rule = repeated_branching_summary.fetch("rules").first

        assert_equal REPEATED_BRANCHING_SUMMARY, rule.slice(*REPEATED_BRANCHING_SUMMARY.keys)
        assert_equal "state", rule.dig("breakdowns", "metadata", "project_analyzer_category").first.fetch("value")
      end

      def merged_service_soup
        write_file("service_soup.rb", SERVICE_SOURCE)
        merge_project_analyzers
      end

      def merged_repeated_branching
        2.times { |index| write_file("branching_#{index}.rb", BRANCHING_SOURCE) }
        merge_project_analyzers
      end

      def merge_project_analyzers
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [@tmpdir])
        end
      end

      def offenses(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }
      end

      def write_file(name, source)
        File.write(File.join(@tmpdir, name), source)
      end
    end
  end
end
