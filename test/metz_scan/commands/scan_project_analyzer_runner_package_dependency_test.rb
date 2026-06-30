# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerPackageDependencyTest < Minitest::Test
      EXTERNAL_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/controllers/refunds_controller.rb", 11],
        ["app/jobs/capture_payment_job.rb", 12],
        ["app/jobs/reconcile_payment_job.rb", 13],
        ["app/mailers/payment_mailer.rb", 14],
        ["app/mailers/refund_mailer.rb", 15],
        ["app/policies/payment_policy.rb", 16],
        ["app/policies/refund_policy.rb", 17],
        ["app/serializers/order_serializer.rb", 18],
        ["app/serializers/refund_serializer.rb", 19],
        ["app/workers/payment_sync_worker.rb", 20],
        ["app/workers/refund_sync_worker.rb", 21]
      ].freeze

      def test_merges_package_dependency_pressure_findings_from_project_index
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: package_dependency_index)

        assert_package_dependency_output(parsed)
      end

      private

      def assert_package_dependency_output(parsed)
        assert_equal 1, package_dependency_offenses(parsed).size
        assert_equal gateway_path, package_dependency_file(parsed).fetch("path")
        assert_package_dependency_metadata(package_dependency_offense(parsed))
        assert_project_analyzer_summary(parsed)
      end

      def assert_package_dependency_metadata(offense)
        assert_package_dependency_declaration_metadata(offense)
        assert_package_dependency_reference_metadata(offense)
        assert_equal "fallback", offense.dig("project_analyzer", "report_location", "line_source")
      end

      def assert_package_dependency_declaration_metadata(offense)
        assert_equal "candidate", offense.dig("project_analyzer", "status")
        assert_equal "Billing::Gateway", offense.dig("project_analyzer", "declaration", "name")
        assert_equal "app/services", offense.dig("project_analyzer", "declared_package")
        assert_equal "package_boundary", offense.dig("project_analyzer", "dependency_pressure_category")
      end

      def assert_package_dependency_reference_metadata(offense)
        assert_equal 12, offense.dig("project_analyzer", "referring_file_count")
        assert_equal %w[app/controllers app/jobs app/mailers app/policies app/serializers app/workers],
                     offense.dig("project_analyzer", "referring_packages")
      end

      def assert_project_analyzer_summary(parsed)
        summary = parsed.fetch("summary").fetch("project_analyzers")

        assert_project_analyzer_counts(summary)
        assert_project_analyzer_rule(summary.fetch("rules").first)
      end

      def assert_project_analyzer_counts(summary)
        assert_equal 1, summary.fetch("finding_count")
        assert_equal 1, summary.fetch("offense_count")
      end

      def assert_project_analyzer_rule(rule)
        assert_equal "MetzProject/PackageDependencyPressure", rule.fetch("cop_name")
        assert_equal "candidate", rule.fetch("status")
        assert_equal "medium", rule.fetch("confidence")
      end

      def package_dependency_offense(parsed)
        package_dependency_offenses(parsed).first
      end

      def package_dependency_offenses(parsed)
        offenses(parsed).select do |candidate|
          candidate.fetch("cop_name") == "MetzProject/PackageDependencyPressure"
        end
      end

      def package_dependency_file(parsed)
        parsed.fetch("files").find do |file|
          file.fetch("offenses").any? do |offense|
            offense.fetch("cop_name") == "MetzProject/PackageDependencyPressure"
          end
        end
      end

      def offenses(parsed)
        parsed.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def package_dependency_index
        ProjectAnalyzerRunnerPackageDependencyIndex.new(
          declarations: gateway_declarations,
          references: { "Billing::Gateway" => external_references }
        )
      end

      def gateway_declarations
        [ProjectIndex::Declaration.new(name: "Billing::Gateway", path: gateway_path, kind: :class)]
      end

      def external_references
        EXTERNAL_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def reference(path, line)
        ProjectIndex::Reference.new(name: "Billing::Gateway", path: "/project/#{path}", line: line, column: 8)
      end

      def gateway_path
        "/project/app/services/billing/gateway.rb"
      end
    end

    class ScanProjectAnalyzerRunnerPackageDependencySharedTriageTest < Minitest::Test
      def test_preserves_shared_dependency_triage_metadata
        assert_shared_dependency_payload(shared_dependency_offense)
      end

      private

      def assert_shared_dependency_payload(offense)
        assert_equal "candidate", offense.dig("project_analyzer", "status")
        assert_equal "low", offense.dig("project_analyzer", "confidence")
        assert_equal "shared dependency", offense.dig("project_analyzer", "triage_severity")
        assert_equal "shared_dependency", offense.dig("project_analyzer", "dependency_pressure_category")
      end

      def shared_dependency_offense
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }
        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: shared_dependency_index)
        package_dependency_offenses(parsed).first
      end

      def package_dependency_offenses(parsed)
        parsed.fetch("files").flat_map { |file| file.fetch("offenses") }.select do |candidate|
          candidate.fetch("cop_name") == "MetzProject/PackageDependencyPressure"
        end
      end

      def shared_dependency_index
        ProjectAnalyzerRunnerPackageDependencyIndex.new(
          declarations: [spree_order_declaration], references: { "Spree::Order" => external_references }
        )
      end

      def spree_order_declaration
        ProjectIndex::Declaration.new(name: "Spree::Order", path: "/project/app/models/spree/order.rb", kind: :class)
      end

      def external_references
        ScanProjectAnalyzerRunnerPackageDependencyTest::EXTERNAL_REFERENCE_PATHS.map do |path, line|
          ProjectIndex::Reference.new(name: "Spree::Order", path: "/project/#{path}", line: line, column: 8)
        end
      end
    end

    class ProjectAnalyzerRunnerPackageDependencyIndex
      def initialize(declarations:, references:)
        @declarations = declarations
        @references = references
      end

      attr_reader :declarations

      def backend_name = :fake

      def available? = true

      def indexed_files = []

      def descendants_of(_name) = []

      def constant_references_to(name) = @references.fetch(name, [])
    end
  end
end
