# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/analyzers/subclass_override_pressure"

module MetzScan
  module Analyzers
    module SubclassOverridePressureAssertionSupport
      private

      def assert_override_finding(finding)
        assert_finding_identity(finding)
        assert_finding_triage(finding)
        assert_finding_metadata(finding)
        assert_report_occurrence(finding)
      end

      def assert_finding_identity(finding)
        assert_equal "MetzProject/SubclassOverridePressure", finding.rule_id
        assert_equal "PaymentProcessor", finding.base_name
        assert_equal "build_client", finding.method_name
        assert_equal %w[BraintreeProcessor PaypalProcessor StripeProcessor], finding.overriding_descendants
        assert_includes finding.message, "PaymentProcessor descendants override build_client"
      end

      def assert_finding_triage(finding)
        assert_equal "candidate", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "manual review", finding.triage_severity
        assert_match(/override/i, finding.triage_summary)
        refute_empty finding.suggested_next_moves
      end

      def assert_finding_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_metadata_identity(metadata)
        assert_metadata_counts(metadata)
        assert_equal expected_override_locations, metadata.fetch("override_locations")
      end

      def assert_metadata_identity(metadata)
        assert_equal "subclass_override", metadata.fetch("subclass_override_category")
        assert_equal "PaymentProcessor", metadata.fetch("base_name")
        assert_equal "build_client", metadata.fetch("method_name")
      end

      def assert_metadata_counts(metadata)
        assert_equal 3, metadata.fetch("override_count")
        assert_equal 4, metadata.fetch("descendant_count")
      end

      def assert_report_occurrence(finding)
        occurrence = finding.report_occurrences.first

        assert_equal "/lib/braintree_processor.rb", occurrence.path
        assert_equal 11, occurrence.report_line
        assert_equal "BraintreeProcessor#build_client", occurrence.context
      end

      def analyze_fake_index
        SubclassOverridePressure.new(index: fake_index, minimum_overriding_descendants: 3).call
      end

      def expected_override_locations
        [{ "owner_name" => "BraintreeProcessor", "path" => "/lib/braintree_processor.rb", "line" => 11 },
         { "owner_name" => "PaypalProcessor", "path" => "/app/models/paypal_processor.rb", "line" => 8 },
         { "owner_name" => "StripeProcessor", "path" => "/app/services/stripe_processor.rb", "line" => 5 }]
      end
    end

    module SubclassOverridePressureFixtureSupport
      private

      def fake_index
        FakeOverrideIndex.new(available: true, descendants: fake_descendants,
                              declarations: fake_declarations, method_declarations: fake_method_declarations)
      end

      def sparse_index
        FakeOverrideIndex.new(available: true, descendants: fake_descendants,
                              declarations: fake_declarations,
                              method_declarations: fake_method_declarations.first(3))
      end

      def unavailable_index
        FakeOverrideIndex.new(available: false, descendants: {}, declarations: [], method_declarations: [])
      end

      def broad_root_index
        FakeOverrideIndex.new(available: true, descendants: broad_root_descendants,
                              declarations: broad_root_declarations,
                              method_declarations: broad_root_method_declarations)
      end

      def fake_descendants
        { "PaymentProcessor" => %w[StripeProcessor PaypalProcessor BraintreeProcessor OtherProcessor] }
      end

      def broad_root_descendants
        { "ApplicationPolicy" => %w[AccountPolicy UserPolicy OrderPolicy] }
      end

      def fake_declarations
        [declaration("PaymentProcessor", "/app/models/payment_processor.rb")] +
          fake_descendants.fetch("PaymentProcessor").map do |name|
            declaration(name, "/app/models/#{name.downcase}.rb")
          end
      end

      def fake_method_declarations
        [method_declaration("PaymentProcessor", "build_client", "/app/models/payment_processor.rb", 2),
         method_declaration("StripeProcessor", "build_client", "/app/services/stripe_processor.rb", 5),
         method_declaration("PaypalProcessor", "build_client", "/app/models/paypal_processor.rb", 8),
         method_declaration("BraintreeProcessor", "build_client", "/lib/braintree_processor.rb", 11),
         method_declaration("OtherProcessor", "render", "/app/controllers/other_processor.rb", 14)]
      end

      def broad_root_declarations
        [declaration("ApplicationPolicy", "/app/policies/application_policy.rb")] +
          broad_root_descendants.fetch("ApplicationPolicy").map do |name|
            declaration(name, "/app/policies/#{name.downcase}.rb")
          end
      end

      def broad_root_method_declarations
        [method_declaration("ApplicationPolicy", "show?", "/app/policies/application_policy.rb", 2),
         method_declaration("AccountPolicy", "show?", "/app/policies/account_policy.rb", 5),
         method_declaration("UserPolicy", "show?", "/app/policies/user_policy.rb", 8),
         method_declaration("OrderPolicy", "show?", "/app/policies/order_policy.rb", 11)]
      end

      def declaration(name, path)
        ProjectIndex::Declaration.new(name: name, path: path, kind: :class)
      end

      def method_declaration(owner_name, method_name, path, line)
        ProjectIndex::MethodDeclaration.new(name: "#{owner_name}##{method_name}()", owner_name: owner_name,
                                            method_name: method_name, signature: "#{method_name}()",
                                            path: path, line: line, column: 3)
      end
    end

    class SubclassOverridePressureTest < Minitest::Test
      include SubclassOverridePressureAssertionSupport
      include SubclassOverridePressureFixtureSupport

      def test_reports_repeated_descendant_overrides_for_same_method
        assert_override_finding(analyze_fake_index.first)
      end

      def test_skips_when_too_few_descendants_override_the_method
        analyzer = SubclassOverridePressure.new(index: sparse_index, minimum_overriding_descendants: 3)

        assert_empty analyzer.call
      end

      def test_downranks_broad_inheritance_roots
        finding = SubclassOverridePressure.new(index: broad_root_index, minimum_overriding_descendants: 3).call.first

        assert_equal "low", finding.confidence
        assert_equal "broad base", finding.triage_severity
        assert_equal "policy base", finding.project_analyzer_metadata.fetch("root_kind")
      end

      def test_skips_when_index_is_unavailable
        analyzer = SubclassOverridePressure.new(index: unavailable_index)

        assert_empty analyzer.call
      end
    end

    class FakeOverrideIndex
      def initialize(available:, descendants:, declarations:, method_declarations:)
        @available = available
        @descendants = descendants
        @declarations = declarations
        @method_declarations = method_declarations
      end

      attr_reader :declarations, :method_declarations

      def backend_name = :fake

      def available? = @available

      def descendants_of(name) = @descendants.fetch(name, [])
    end
  end
end
