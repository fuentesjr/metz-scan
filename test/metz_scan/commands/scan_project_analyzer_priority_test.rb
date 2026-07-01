# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerPriorityTest < Minitest::Test
      SERVICE_SOURCE = <<~RUBY
        class OrdersController
          def create
            ValidateOrder.call(order)
            ReserveInventory.call(order)
            CapturePayment.new(order).call
          end
        end
      RUBY
      SETUP_SERVICE_SOURCE = <<~RUBY
        module Spree
          module Seeds
            class All
              def call
                Countries.call
                States.call
                Zones.call
              end
            end
          end
        end
      RUBY

      def setup
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzer-priority-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_summary_uses_highest_priority_triage_for_mixed_rule_findings
        assert_normal_service_soup_summary(service_soup_rule_summary(mixed_service_soup_summary))
      end

      def test_metadata_summary_uses_highest_priority_triage_for_rule
        summary = service_soup_rule_summary(mixed_priority_metadata_summary)

        assert_equal "medium", summary.fetch("confidence")
        assert_equal "design pressure", summary.fetch("triage_severity")
      end

      def test_metadata_summary_includes_rule_breakdowns
        breakdowns = service_soup_rule_summary(mixed_priority_metadata_summary).fetch("breakdowns")

        assert_breakdown [["low", 1], ["medium", 1]], breakdowns.fetch("confidence")
        assert_breakdown [["design pressure", 1], ["setup orchestration", 1]], breakdowns.fetch("triage_severity")
      end

      private

      def assert_normal_service_soup_summary(summary)
        assert_equal "medium", summary.fetch("confidence")
        assert_equal "design pressure", summary.fetch("triage_severity")
        assert_equal 2, summary.fetch("finding_count")
        assert_equal 6, summary.fetch("offense_count")
      end

      def service_soup_rule_summary(summary)
        summary.fetch("rules").find { |rule| rule.fetch("cop_name") == "MetzProject/ServiceSoup" }
      end

      def mixed_service_soup_summary
        write_file("00_setup_service_soup.rb", SETUP_SERVICE_SOURCE)
        write_file("99_service_soup.rb", SERVICE_SOURCE)
        merge_project_analyzers.dig("summary", "project_analyzers")
      end

      def mixed_priority_metadata_summary
        Scan::ProjectAnalyzerMetadata.summary(mixed_priority_findings, service_soup_offenses(2))
      end

      def mixed_priority_findings
        [service_finding("validated", "low", "setup orchestration"),
         service_finding("validated", "medium", "design pressure")]
      end

      def service_finding(status, confidence, triage_severity)
        Struct.new(:rule_id, :project_analyzer_status, :confidence, :triage_severity, keyword_init: true)
              .new(rule_id: "MetzProject/ServiceSoup", project_analyzer_status: status,
                   confidence: confidence, triage_severity: triage_severity)
      end

      def service_soup_offenses(count)
        Array.new(count) { { "cop_name" => "MetzProject/ServiceSoup" } }
      end

      def assert_breakdown(expected, actual)
        assert_equal expected.map { |value, count| { "value" => value, "finding_count" => count } }, actual
      end

      def merge_project_analyzers
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [@tmpdir])
        end
      end

      def write_file(name, source)
        File.write(File.join(@tmpdir, name), source)
      end
    end

    class ScanProjectAnalyzerTriagePriorityTest < Minitest::Test
      def test_validated_status_sorts_before_candidate
        assert_prioritized({ "status" => "validated" }, over: { "status" => "candidate" })
      end

      def test_manual_review_sorts_before_shared_dependency
        assert_prioritized low_metadata("manual review"), over: low_metadata("shared dependency")
      end

      def test_broad_base_sorts_before_shared_dependency
        assert_prioritized low_metadata("broad base"), over: low_metadata("shared dependency")
      end

      def test_context_required_sorts_after_manual_review_before_broad_base
        assert_prioritized low_metadata("manual review"), over: low_metadata("context required")
        assert_prioritized low_metadata("context required"), over: low_metadata("broad base")
      end

      def test_low_confidence_severities_sort_in_triage_order
        sort_keys = ["shared dependency", "shared namespace", "setup orchestration"]
                    .map { |severity| priority.sort_key(low_metadata(severity)) }

        assert_equal sort_keys.sort, sort_keys
      end

      private

      def assert_prioritized(metadata, over:)
        assert_equal(-1, priority.sort_key(metadata) <=> priority.sort_key(over))
      end

      def low_metadata(triage_severity)
        { "status" => "experimental", "confidence" => "low", "triage_severity" => triage_severity }
      end

      def priority
        Scan::ProjectAnalyzerTriagePriority
      end
    end
  end
end
