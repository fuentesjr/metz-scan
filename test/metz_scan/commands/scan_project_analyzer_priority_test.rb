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

      def test_validated_status_sorts_before_candidate
        priority = Scan::ProjectAnalyzerTriagePriority

        assert_equal(-1, priority.sort_key("status" => "validated") <=> priority.sort_key("status" => "candidate"))
      end

      def test_manual_review_sorts_before_shared_dependency
        priority = Scan::ProjectAnalyzerTriagePriority

        manual = { "status" => "experimental", "confidence" => "low", "triage_severity" => "manual review" }
        shared = { "status" => "experimental", "confidence" => "low", "triage_severity" => "shared dependency" }

        assert_equal(-1, priority.sort_key(manual) <=> priority.sort_key(shared))
      end

      def test_broad_base_sorts_before_shared_dependency
        priority = Scan::ProjectAnalyzerTriagePriority

        broad_base = { "status" => "experimental", "confidence" => "low", "triage_severity" => "broad base" }
        shared = { "status" => "experimental", "confidence" => "low", "triage_severity" => "shared dependency" }

        assert_equal(-1, priority.sort_key(broad_base) <=> priority.sort_key(shared))
      end

      def test_low_confidence_severities_sort_in_triage_order
        priority = Scan::ProjectAnalyzerTriagePriority
        severities = ["shared dependency", "shared namespace", "setup orchestration"]
        sort_keys = severities.map { |severity| priority.sort_key(low_experimental_metadata(severity)) }

        assert_equal sort_keys.sort, sort_keys
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

      def low_experimental_metadata(triage_severity)
        { "status" => "experimental", "confidence" => "low", "triage_severity" => triage_severity }
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
  end
end
