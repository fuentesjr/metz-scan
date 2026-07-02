# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"

require "metz_scan/analyzers/namespace_leak_pressure"

module MetzScan
  module Analyzers
    module NamespaceLeakPressureTestSupport
      EXTERNAL_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/jobs/capture_payment_job.rb", 11],
        ["app/mailers/receipt_mailer.rb", 12]
      ].freeze
      TWO_PACKAGE_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/jobs/capture_payment_job.rb", 11]
      ].freeze
      NOISY_REFERENCE_PATHS = [
        ["app/models/billing/ledger/private_formatter.rb", 2],
        ["app/models/billing/ledger/entry.rb", 4],
        ["app/services/billing/ledger/reconciler.rb", 5],
        ["test/models/billing/ledger/private_formatter_test.rb", 6],
        ["spec/models/billing/ledger/private_formatter_spec.rb", 7],
        ["lib/tasks/billing.rake", 8],
        ["lib/seeders/billing_seeder.rb", 9],
        ["lib/seed_data/billing_seed.rb", 10],
        ["lib/test_data/billing_formatter_factory.rb", 11],
        ["lib/generators/billing/install_generator.rb", 12]
      ].freeze
      NESTED_SUPPORT_REFERENCE_PATHS = [
        ["app/services/spree/seeds/digital_delivery.rb", 22],
        ["lib/spree/testing_support/factories/calculator_factory.rb", 23]
      ].freeze

      def leaking_index
        leak_index(references: external_references)
      end

      def below_threshold_index
        leak_index(references: external_references.first(1))
      end

      def two_package_index
        leak_index(references: two_package_references)
      end

      def noisy_reference_index
        leak_index(references: noisy_references + external_references)
      end

      def nested_support_reference_index
        leak_index(references: nested_support_references + external_references)
      end

      def public_namespace_root_index
        leak_index(name: "Billing::Ledger", references: external_references)
      end

      def setup_declaration_index
        leak_index(path: "/project/lib/tasks/private_formatter.rb", references: external_references)
      end

      def parent_named_namespace_index
        leak_index(path: parent_named_formatter_path, references: parent_named_references)
      end

      def leak_index(available: true, name: "Billing::Ledger::PrivateFormatter", path: formatter_path, references: [])
        FakeNamespaceLeakIndex.new(available: available, declarations: declarations_for(name, path),
                                   references: { name => references })
      end

      def declarations_for(name, path)
        [ProjectIndex::Declaration.new(name: name, path: path, kind: :class)]
      end

      def external_references
        EXTERNAL_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def two_package_references
        TWO_PACKAGE_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def noisy_references
        NOISY_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def nested_support_references
        NESTED_SUPPORT_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def parent_named_references
        EXTERNAL_REFERENCE_PATHS.map do |path, line|
          ProjectIndex::Reference.new(name: "Billing::Ledger::PrivateFormatter",
                                      path: "#{parent_named_project_root}/#{path}", line: line, column: 8)
        end
      end

      def reference(path, line)
        reference_for("Billing::Ledger::PrivateFormatter", path, line)
      end

      def reference_for(name, path, line)
        ProjectIndex::Reference.new(name: name, path: "/project/#{path}", line: line, column: 8)
      end

      def formatter_path
        "/project/app/models/billing/ledger/private_formatter.rb"
      end

      def parent_named_formatter_path
        "#{parent_named_project_root}/app/models/billing/ledger/private_formatter.rb"
      end

      def parent_named_project_root
        "/tmp/spec/app/project"
      end
    end

    class NamespaceLeakPressureDetectionTest < Minitest::Test
      include NamespaceLeakPressureTestSupport

      def test_reports_nested_declarations_referenced_outside_home_namespace
        finding = NamespaceLeakPressure.new(index: leaking_index).call.first

        assert_namespace_leak_finding(finding)
        assert_namespace_leak_metadata(finding)
      end

      def test_classifies_home_namespace_from_project_paths_not_parent_directories
        finding = NamespaceLeakPressure.new(index: parent_named_namespace_index).call.first

        assert_equal parent_named_formatter_path, finding.report_occurrences.first.path
        assert_equal "Billing::Ledger", finding.home_namespace
      end

      private

      def assert_namespace_leak_finding(finding)
        assert_namespace_leak_identity(finding)
        assert_namespace_leak_triage(finding)
        assert_equal [formatter_path], finding.report_occurrences.map(&:path)
      end

      def assert_namespace_leak_identity(finding)
        assert_equal "MetzProject/NamespaceLeakPressure", finding.rule_id
        assert_equal "Billing::Ledger::PrivateFormatter", finding.declaration_name
        assert_equal "Billing::Ledger", finding.home_namespace
        assert_includes finding.message, "Billing::Ledger::PrivateFormatter is referenced from 3 files"
        assert_includes finding.message, "outside Billing::Ledger"
      end

      def assert_namespace_leak_triage(finding)
        assert_equal "candidate", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "manual review", finding.triage_severity
        assert_includes finding.triage_summary, "Candidate namespace-boundary signal"
      end

      def assert_namespace_leak_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_declaration_metadata(metadata)
        assert_reference_metadata(metadata)
      end

      def assert_declaration_metadata(metadata)
        assert_equal({ "name" => "Billing::Ledger::PrivateFormatter", "kind" => "class", "path" => formatter_path },
                     metadata.fetch("declaration"))
        assert_equal "Billing::Ledger", metadata.fetch("home_namespace")
        assert_equal "app/models", metadata.fetch("declared_package")
        assert_equal "namespace_boundary", metadata.fetch("namespace_leak_category")
      end

      def assert_reference_metadata(metadata)
        assert_reference_counts(metadata)
        assert_reference_shape(metadata.fetch("reference_shape"))
        assert_equal 3, metadata.fetch("references").size
      end

      def assert_reference_counts(metadata)
        assert_equal 3, metadata.fetch("referring_file_count")
        assert_equal 3, metadata.fetch("referring_package_count")
        assert_equal %w[app/controllers app/jobs app/mailers], metadata.fetch("referring_packages")
      end

      def assert_reference_shape(reference_shape)
        assert_equal ["app"], reference_shape.fetch("referring_package_roots")
        assert_equal %w[controllers jobs mailers],
                     reference_shape.fetch("referring_package_leafs")
      end
    end

    class NamespaceLeakPressureFilteringTest < Minitest::Test
      include NamespaceLeakPressureTestSupport

      def test_ignores_unavailable_index
        assert_empty NamespaceLeakPressure.new(index: leak_index(available: false)).call
      end

      def test_ignores_declarations_below_thresholds
        assert_empty NamespaceLeakPressure.new(index: below_threshold_index).call
      end

      def test_default_threshold_requires_three_files_across_three_packages
        assert_empty NamespaceLeakPressure.new(index: two_package_index).call
      end

      def test_ignores_public_namespace_roots
        assert_empty NamespaceLeakPressure.new(index: public_namespace_root_index).call
      end

      def test_ignores_same_namespace_setup_and_self_references
        finding = NamespaceLeakPressure.new(index: noisy_reference_index).call.first

        assert_equal 3, finding.referring_files.size
        assert_equal %w[app/controllers app/jobs app/mailers], finding.referring_packages
      end

      def test_ignores_nested_setup_and_support_references
        finding = NamespaceLeakPressure.new(index: nested_support_reference_index).call.first

        assert_equal 3, finding.referring_files.size
        assert_equal %w[app/controllers app/jobs app/mailers], finding.referring_packages
      end

      def test_ignores_declarations_in_setup_paths
        assert_empty NamespaceLeakPressure.new(index: setup_declaration_index).call
      end
    end

    class NamespaceLeakPressureSharedNamespaceTest < Minitest::Test
      include NamespaceLeakPressureTestSupport

      STANDARD_ERROR_ASSIGNMENT_SOURCE = <<~RUBY
        module Compression
          class Strategy
            ExtractFailed = Class.new(StandardError)
          end
        end
      RUBY

      def test_downranks_constant_namespaces
        finding = finding_for_shared("Events::Types::ASSIGNEE_CHANGED", "/project/lib/events/types.rb")

        assert_shared_namespace_triage(finding)
      end

      def test_downranks_nested_error_families
        finding = finding_for_shared("Github::Errors::NotFound", "/project/app/services/github/errors.rb")

        assert_shared_namespace_triage(finding)
      end

      def test_downranks_exception_family_segments_with_prefixes
        finding = finding_for_shared("CustomExceptions::CustomFilter::InvalidValue",
                                     "/project/lib/custom_exceptions/custom_filter.rb")

        assert_shared_namespace_triage(finding)
      end

      def test_downranks_standard_error_assignments_without_error_suffix
        with_standard_error_assignment do |path|
          finding = finding_for_shared("Compression::Strategy::ExtractFailed", path)

          assert_shared_namespace_triage(finding)
        end
      end

      def test_downranks_registry_extension_points
        finding = finding_for_shared("AdminDashboard::Reports::Registry",
                                     "/project/lib/admin_dashboard/reports/registry.rb")

        assert_shared_namespace_triage(finding)
      end

      def test_downranks_framework_extension_namespaces
        finding = finding_for_shared("Spree::Core::Engine", "/project/lib/spree/core/engine.rb")

        assert_shared_namespace_triage(finding)
      end

      private

      def with_standard_error_assignment
        Dir.mktmpdir do |dir|
          path = File.join(dir, "lib/compression/strategy.rb")
          write_standard_error_assignment(path)
          yield path
        end
      end

      def write_standard_error_assignment(path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, STANDARD_ERROR_ASSIGNMENT_SOURCE)
      end

      def finding_for_shared(name, path)
        NamespaceLeakPressure.new(index: shared_namespace_index(name, path)).call.first
      end

      def shared_namespace_index(name, path)
        leak_index(name: name, path: path, references: shared_namespace_references(name))
      end

      def shared_namespace_references(name)
        [
          reference_for(name, "app/controllers/orders_controller.rb", 10),
          reference_for(name, "app/jobs/capture_payment_job.rb", 11),
          reference_for(name, "app/models/order.rb", 12)
        ]
      end

      def assert_shared_namespace_triage(finding)
        assert_equal "low", finding.confidence
        assert_equal "shared namespace", finding.triage_severity
        assert_includes finding.triage_summary, "Shared namespace signal"
        assert_equal "shared_namespace", finding.project_analyzer_metadata.fetch("namespace_leak_category")
      end
    end

    class FakeNamespaceLeakIndex
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
