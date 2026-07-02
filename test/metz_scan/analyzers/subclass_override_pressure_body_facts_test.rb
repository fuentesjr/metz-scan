# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/subclass_override_pressure"

module MetzScan
  module Analyzers
    module SubclassOverridePressureBodyFactsAssertions
      private

      def assert_override_calls_super(metadata, owner_name, expected)
        override = metadata.fetch("override_locations").find { |location| location.fetch("owner_name") == owner_name }

        assert_equal expected, override.fetch("calls_super")
      end

      def assert_abstract_hook_metadata(metadata)
        assert_equal "abstract_hook_override", metadata.fetch("subclass_override_category")
        assert_equal "abstract_raise", metadata.fetch("base_method_body_kind")
        assert_equal 1, metadata.fetch("overrides_calling_super_count")
        assert_override_calls_super(metadata, "StripeProcessor", true)
        assert_override_calls_super(metadata, "PaypalProcessor", false)
      end

      def assert_cooperative_metadata(metadata)
        assert_equal "cooperative_override", metadata.fetch("subclass_override_category")
        assert_equal "concrete", metadata.fetch("base_method_body_kind")
        assert_equal 2, metadata.fetch("overrides_calling_super_count")
      end

      def assert_default_hook_metadata(metadata)
        assert_equal "abstract_hook_override", metadata.fetch("subclass_override_category")
        assert_equal "default_value", metadata.fetch("base_method_body_kind")
        assert_equal 0, metadata.fetch("overrides_calling_super_count")
      end

      def assert_abstract_hook_triage(finding)
        assert_includes finding.message, "implement build_client as an abstract hook"
        assert_includes finding.triage_summary, "abstract hook"
        assert_includes finding.why_it_matters, "implicit protocol"
        assert_includes finding.suggested_next_moves.join(" "), "Name the hook contract"
      end

      def assert_cooperative_triage(finding)
        assert_includes finding.message, "extend normalize with super"
        assert_includes finding.triage_summary, "super"
        assert_includes finding.why_it_matters, "template-method"
        assert_includes finding.suggested_next_moves.join(" "), "Keep cooperative hooks"
      end

      def assert_replacement_metadata(metadata)
        assert_equal "replacement_override", metadata.fetch("subclass_override_category")
        assert_equal "concrete", metadata.fetch("base_method_body_kind")
        assert_equal 0, metadata.fetch("overrides_calling_super_count")
      end

      def assert_replacement_triage(finding)
        assert_includes finding.message, "replace concrete serialize behavior"
        assert_includes finding.triage_summary, "replace concrete base behavior"
        assert_includes finding.why_it_matters, "substitution"
        assert_includes finding.suggested_next_moves.join(" "), "composition"
      end
    end

    module SubclassOverridePressureBodyFactsSupport
      private

      def analyze(index)
        SubclassOverridePressure.new(index: index, minimum_overriding_descendants: 3).call
      end

      def abstract_hook_index
        body_fact_index("PaymentProcessor", "build_client", abstract_base_source, abstract_override_sources)
      end

      def cooperative_index
        body_fact_index("EnvelopeNormalizer", "normalize", concrete_base_source, cooperative_override_sources)
      end

      def default_hook_index
        body_fact_index("TagRule", "tags", default_base_source, default_override_sources)
      end

      def body_fact_index(base_name, method_name, base_source, override_sources)
        BodyFactIndex.new(base_declaration(base_name), descendants_for(override_sources),
                          method_declarations(base_name, method_name, base_source, override_sources))
      end

      def base_declaration(base_name)
        ProjectIndex::Declaration.new(name: base_name, path: path_for("#{base_name}.rb"), kind: :class)
      end

      def descendants_for(override_sources)
        override_sources.keys.sort
      end

      def method_declarations(base_name, method_name, base_source, override_sources)
        [method_declaration(base_name, method_name, write_source(base_name, base_source))] +
          override_sources.map do |owner_name, source|
            method_declaration(owner_name, method_name, write_source(owner_name, source))
          end
      end

      def method_declaration(owner_name, method_name, path)
        ProjectIndex::MethodDeclaration.new(name: "#{owner_name}##{method_name}()", owner_name: owner_name,
                                            method_name: method_name, signature: "#{method_name}()",
                                            path: path, line: method_line(path, method_name), column: 3)
      end

      def write_source(owner_name, source)
        path_for("#{owner_name}.rb").tap do |path|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, source)
        end
      end

      def method_line(path, method_name)
        File.readlines(path).find_index { |line| line.include?("def #{method_name}") } + 1
      end

      def path_for(filename)
        File.join(@tmpdir, filename)
      end

      def abstract_base_source
        <<~RUBY
          class PaymentProcessor
            def build_client
              raise NotImplementedError, "subclasses must implement"
            end
          end
        RUBY
      end

      def abstract_override_sources
        { "StripeProcessor" => override_source("build_client", "super.configure"),
          "PaypalProcessor" => override_source("build_client", "PaypalClient.new"),
          "BraintreeProcessor" => override_source("build_client", "BraintreeClient.new") }
      end

      def concrete_base_source
        <<~RUBY
          class EnvelopeNormalizer
            def normalize(payload)
              payload.compact
            end
          end
        RUBY
      end

      def cooperative_override_sources
        { "JsonNormalizer" => override_source("normalize", "super.merge(format: :json)"),
          "XmlNormalizer" => override_source("normalize", "super.merge(format: :xml)"),
          "CsvNormalizer" => override_source("normalize", "{ format: :csv }") }
      end

      def default_base_source
        <<~RUBY
          class TagRule
            def tags
              []
            end
          end
        RUBY
      end

      def default_override_sources
        { "ProductTagRule" => override_source("tags", "%w[local fresh]"),
          "OrderTagRule" => override_source("tags", "%w[wholesale]"),
          "CustomerTagRule" => override_source("tags", "%w[member]") }
      end

      def override_source(method_name, body)
        <<~RUBY
          class Example
            def #{method_name}
              #{body}
            end
          end
        RUBY
      end
    end

    module SubclassOverridePressureReplacementFactsSupport
      private

      def replacement_index
        body_fact_index("PayloadRenderer", "serialize", concrete_renderer_source, replacement_override_sources)
      end

      def concrete_renderer_source
        <<~RUBY
          class PayloadRenderer
            def serialize(payload)
              payload.to_h
            end
          end
        RUBY
      end

      def replacement_override_sources
        { "JsonRenderer" => override_source("serialize", "JSON.generate(payload)"),
          "XmlRenderer" => override_source("serialize", "XmlDocument.build(payload)"),
          "CsvRenderer" => override_source("serialize", "CsvDocument.build(payload)") }
      end
    end

    class SubclassOverridePressureBodyFactsTest < Minitest::Test
      include SubclassOverridePressureBodyFactsAssertions
      include SubclassOverridePressureBodyFactsSupport
      include SubclassOverridePressureReplacementFactsSupport

      def setup
        @tmpdir = Dir.mktmpdir("subclass-override-body-facts")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_records_abstract_base_method_and_super_call_metadata
        finding = analyze(abstract_hook_index).first

        assert_abstract_hook_metadata(finding.project_analyzer_metadata)
        assert_abstract_hook_triage(finding)
      end

      def test_classifies_concrete_override_families_with_super_as_cooperative
        finding = analyze(cooperative_index).first

        assert_cooperative_metadata(finding.project_analyzer_metadata)
        assert_cooperative_triage(finding)
      end

      def test_classifies_default_value_base_methods_as_abstract_hooks
        assert_default_hook_metadata(analyze(default_hook_index).first.project_analyzer_metadata)
      end

      def test_classifies_concrete_override_families_without_super_as_replacements
        finding = analyze(replacement_index).first

        assert_replacement_metadata(finding.project_analyzer_metadata)
        assert_replacement_triage(finding)
      end
    end

    class BodyFactIndex
      def initialize(base_declaration, descendants, method_declarations)
        @base_declaration = base_declaration
        @descendants = descendants
        @method_declarations = method_declarations
      end

      attr_reader :method_declarations

      def backend_name = :fake

      def available? = true

      def declarations = [@base_declaration]

      def descendants_of(_name) = @descendants
    end
  end
end
