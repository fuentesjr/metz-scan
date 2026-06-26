# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/analyzers/package_dependency_pressure"

module MetzScan
  module Analyzers
    class PackageDependencyPressureTest < Minitest::Test
      EXTERNAL_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/controllers/refunds_controller.rb", 11],
        ["app/jobs/capture_payment_job.rb", 12],
        ["app/jobs/reconcile_payment_job.rb", 13],
        ["app/mailers/payment_mailer.rb", 14],
        ["app/mailers/refund_mailer.rb", 15],
        ["app/serializers/order_serializer.rb", 16],
        ["app/serializers/refund_serializer.rb", 17],
        ["app/workers/payment_sync_worker.rb", 18],
        ["app/workers/refund_sync_worker.rb", 19],
        ["app/policies/payment_policy.rb", 20],
        ["app/policies/refund_policy.rb", 21]
      ].freeze
      NOISY_REFERENCE_PATHS = [
        ["app/services/billing/gateway.rb", 2],
        ["app/services/billing/gateway_factory.rb", 4],
        ["test/services/billing/gateway_test.rb", 5],
        ["spec/services/billing/gateway_spec.rb", 6],
        ["lib/tasks/billing.rake", 7],
        ["lib/seeders/billing_seeder.rb", 8],
        ["lib/seed_data/billing_seed.rb", 9],
        ["lib/test_data/billing_gateway_factory.rb", 10],
        ["lib/generators/billing/install_generator.rb", 11]
      ].freeze

      def test_reports_declarations_referenced_across_external_packages
        finding = PackageDependencyPressure.new(index: pressured_index).call.first

        assert_package_pressure_finding(finding)
        assert_package_pressure_metadata(finding)
      end

      def test_ignores_unavailable_index
        assert_empty PackageDependencyPressure.new(index: pressure_index(available: false)).call
      end

      def test_ignores_declarations_below_thresholds
        findings = PackageDependencyPressure.new(index: below_threshold_index).call

        assert_empty findings
      end

      def test_ignores_top_level_namespace_declarations
        findings = PackageDependencyPressure.new(index: top_level_namespace_index).call

        assert_empty findings
      end

      def test_ignores_same_package_test_setup_and_self_references
        finding = PackageDependencyPressure.new(index: noisy_reference_index).call.first

        assert_equal 12, finding.referring_files.size
        assert_equal %w[app/controllers app/jobs app/mailers app/policies app/serializers app/workers],
                     finding.referring_packages
      end

      def test_ignores_declarations_in_setup_paths
        findings = PackageDependencyPressure.new(index: setup_declaration_index).call

        assert_empty findings
      end

      def test_downranks_shared_dependency_declarations
        finding = PackageDependencyPressure.new(index: shared_dependency_index).call.first

        assert_shared_dependency_triage(finding)
      end

      def test_downranks_infrastructure_lib_declarations
        finding = PackageDependencyPressure.new(index: infrastructure_dependency_index).call.first

        assert_shared_dependency_triage(finding)
      end

      private

      def assert_package_pressure_finding(finding)
        assert_package_identity(finding)
        assert_package_triage(finding)
        assert_equal [gateway_path], finding.report_occurrences.map(&:path)
      end

      def assert_package_identity(finding)
        assert_equal "MetzProject/PackageDependencyPressure", finding.rule_id
        assert_equal "Billing::Gateway", finding.declaration_name
        assert_includes finding.message, "Billing::Gateway is referenced from 12 files across 6 packages"
        assert_includes finding.message, "outside app/services"
      end

      def assert_package_triage(finding)
        assert_equal "experimental", finding.project_analyzer_status
        assert_equal "early", finding.confidence
        assert_equal "manual review", finding.triage_severity
      end

      def assert_package_pressure_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_equal({ "name" => "Billing::Gateway", "kind" => "class", "path" => gateway_path },
                     metadata.fetch("declaration"))
        assert_package_pressure_counts(metadata)
      end

      def assert_package_pressure_counts(metadata)
        assert_equal "app/services", metadata.fetch("declared_package")
        assert_equal 12, metadata.fetch("referring_file_count")
        assert_equal 6, metadata.fetch("referring_package_count")
        assert_equal "package_boundary", metadata.fetch("dependency_pressure_category")
        assert_equal %w[app/controllers app/jobs app/mailers app/policies app/serializers app/workers],
                     metadata.fetch("referring_packages")
        assert_equal 12, metadata.fetch("references").size
      end

      def assert_shared_dependency_triage(finding)
        assert_equal "low", finding.confidence
        assert_equal "shared dependency", finding.triage_severity
        assert_includes finding.triage_summary, "Shared dependency signal"
        assert_equal "shared_dependency", finding.project_analyzer_metadata.fetch("dependency_pressure_category")
      end

      def pressured_index
        pressure_index(references: external_references)
      end

      def below_threshold_index
        pressure_index(references: external_references.first(3))
      end

      def noisy_reference_index
        pressure_index(references: noisy_references)
      end

      def top_level_namespace_index
        pressure_index(name: "RuboCop", references: external_references)
      end

      def setup_declaration_index
        FakePackagePressureIndex.new(
          available: true,
          declarations: [
            ProjectIndex::Declaration.new(name: "Billing::Gateway", path: "/project/lib/tasks/billing_gateway.rb",
                                          kind: :class)
          ],
          references: { "Billing::Gateway" => external_references }
        )
      end

      def shared_dependency_index
        pressure_index(name: "Settings::General", path: "/project/app/models/settings/general.rb",
                       references: external_references)
      end

      def infrastructure_dependency_index
        pressure_index(name: "Redis::Alfred", path: "/project/lib/redis/alfred.rb",
                       references: external_references)
      end

      def pressure_index(available: true, name: "Billing::Gateway", path: gateway_path, references: [])
        FakePackagePressureIndex.new(
          available: available, declarations: gateway_declarations(name, path),
          references: { name => references }
        )
      end

      def gateway_declarations(name, path = gateway_path)
        [ProjectIndex::Declaration.new(name: name, path: path, kind: :class)]
      end

      def external_references
        EXTERNAL_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def noisy_references
        NOISY_REFERENCE_PATHS.map { |path, line| reference(path, line) } + external_references
      end

      def reference(path, line)
        ProjectIndex::Reference.new(name: "Billing::Gateway", path: "/project/#{path}", line: line, column: 8)
      end

      def gateway_path
        "/project/app/services/billing/gateway.rb"
      end
    end

    class FakePackagePressureIndex
      def initialize(available:, declarations:, references:)
        @available = available
        @declarations = declarations
        @references = references
      end

      attr_reader :declarations

      def backend_name = :fake

      def available? = @available

      def constant_references_to(name) = @references.fetch(name, [])
    end
  end
end
