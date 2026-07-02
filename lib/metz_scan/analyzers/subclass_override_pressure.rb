# frozen_string_literal: true

require_relative "../project_index"
require_relative "inheritance_descendants/root_kind"
require_relative "project_analyzer_triage"
require_relative "subclass_override_pressure/family_builder"
require_relative "subclass_override_pressure/finding"
require_relative "subclass_override_pressure/metadata"
require_relative "subclass_override_pressure/method_body_facts"
require_relative "subclass_override_pressure/triage"

module MetzScan
  module Analyzers
    # Reports base classes whose descendants repeatedly override the same method.
    class SubclassOverridePressure
      include ProjectAnalyzerTriage
      include FamilyBuilder
      include Metadata
      include Triage

      RULE_ID = "MetzProject/SubclassOverridePressure"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate subclass override signal; review whether shared hooks hide coupling."
      BROAD_ROOT_CONFIDENCE = "low"
      BROAD_ROOT_TRIAGE_SEVERITY = "broad base"
      BROAD_ROOT_TRIAGE_SUMMARY = "Broad inheritance base with repeated overrides; review only when hook " \
                                  "changes frequently or subclasses diverge."
      WHY = "Repeated subclass overrides can turn inheritance into an implicit protocol that is hard to change."
      SUGGESTED_NEXT_MOVES = [
        "Review whether the base class is defining a hook protocol that should be explicit.",
        "Prefer composition when subclasses override the same behavior for unrelated reasons."
      ].freeze
      MINIMUM_OVERRIDING_DESCENDANTS = 6
      IGNORED_DECLARATION_NAMES = %w[BasicObject Class Kernel Module Object].freeze
      SYNTHETIC_DECLARATION_MARKER = "::<"
      private_constant :IGNORED_DECLARATION_NAMES, :SYNTHETIC_DECLARATION_MARKER

      OverrideFamily = Struct.new(:base, :base_method, :method_name, :descendants, :overrides, :root_kind,
                                  :base_method_body_kind, :override_body_facts, keyword_init: true) do
        def overrides_calling_super_count
          override_body_facts.values.count(&:calls_super)
        end
      end

      def initialize(paths: nil, index: nil, base_names: nil,
                     minimum_overriding_descendants: MINIMUM_OVERRIDING_DESCENDANTS)
        @paths = Array(paths)
        @index = index || ProjectIndex.build(@paths)
        @base_names = Array(base_names).compact
        @minimum_overriding_descendants = minimum_overriding_descendants
      end

      def call
        return [] unless index.available?

        base_candidates.flat_map { |base| findings_for(base) }
      end

      private

      attr_reader :index, :base_names, :minimum_overriding_descendants

      def override_family(base, base_method, descendants, overrides)
        OverrideFamily.new(base: base, base_method: base_method, method_name: base_method.method_name,
                           descendants: descendants, overrides: overrides,
                           root_kind: InheritanceDescendants::RootKind.for(base.name),
                           base_method_body_kind: body_facts_for(base_method).body_kind,
                           override_body_facts: override_body_facts_for(overrides))
      end

      def finding_attributes(family)
        core_finding_attributes(family)
          .merge(triage_attributes_for(family))
          .merge(project_analyzer_context_attributes(family))
      end

      def core_finding_attributes(family)
        { source: source_name, rule_id: RULE_ID, message: message_for(family),
          base_name: family.base.name, method_name: family.method_name, descendant_count: family.descendants.size,
          overriding_descendants: family.overrides.map(&:owner_name), occurrences: family.overrides }
      end

      def declarations_by_name
        @declarations_by_name ||= index.declarations.to_h { |declaration| [declaration.name, declaration] }
      end

      def methods_by_owner
        @methods_by_owner ||= index.method_declarations.group_by(&:owner_name)
      end

      def override_body_facts_for(overrides)
        overrides.to_h { |override| [override.owner_name, body_facts_for(override)] }
      end

      def body_facts_for(declaration)
        body_facts.for(declaration)
      end

      def body_facts
        @body_facts ||= MethodBodyFacts.new
      end

      def ignored_declaration_name?(name)
        IGNORED_DECLARATION_NAMES.include?(name) || name.include?(SYNTHETIC_DECLARATION_MARKER)
      end
    end
  end
end
