# frozen_string_literal: true

require_relative "../project_index"
require_relative "inheritance_descendants/root_kind"
require_relative "project_analyzer_triage"
require_relative "subclass_override_pressure/finding"
require_relative "subclass_override_pressure/metadata"

module MetzScan
  module Analyzers
    # Reports base classes whose descendants repeatedly override the same method.
    class SubclassOverridePressure
      include ProjectAnalyzerTriage
      include Metadata

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

      OverrideFamily = Struct.new(:base, :method_name, :descendants, :overrides, :root_kind, keyword_init: true)

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

      def base_candidates
        return configured_base_candidates unless base_names.empty?

        auto_discovered_base_candidates
      end

      def configured_base_candidates
        base_names.filter_map { |name| declarations_by_name[name] }
      end

      def auto_discovered_base_candidates
        index.declarations.select { |declaration| auto_discovered_base_candidate?(declaration) }
      end

      def auto_discovered_base_candidate?(declaration)
        declaration.name && declaration.path && class_candidate?(declaration) &&
          !ignored_declaration_name?(declaration.name)
      end

      def class_candidate?(declaration)
        !declaration.respond_to?(:kind) || declaration.kind.nil? || declaration.kind == :class
      end

      def findings_for(base)
        descendants = sorted_descendants(base.name)
        return [] if descendants.size < minimum_overriding_descendants

        base_method_names(base).filter_map { |method_name| finding_for(base, method_name, descendants) }
      end

      def sorted_descendants(base_name)
        index.descendants_of(base_name).reject { |name| ignored_declaration_name?(name) }.sort
      end

      def base_method_names(base)
        methods_by_owner.fetch(base.name, []).map(&:method_name).uniq.sort
      end

      def finding_for(base, method_name, descendants)
        overrides = overrides_for(method_name, descendants)
        return if overrides.size < minimum_overriding_descendants

        Finding.new(finding_attributes(override_family(base, method_name, descendants, overrides)))
      end

      def overrides_for(method_name, descendants)
        descendants.filter_map { |descendant| method_declaration_for(descendant, method_name) }
                   .sort_by { |declaration| declaration.owner_name.to_s }
      end

      def method_declaration_for(owner_name, method_name)
        methods_by_owner.fetch(owner_name, []).find { |declaration| declaration.method_name == method_name }
      end

      def override_family(base, method_name, descendants, overrides)
        OverrideFamily.new(base: base, method_name: method_name, descendants: descendants, overrides: overrides,
                           root_kind: InheritanceDescendants::RootKind.for(base.name))
      end

      def finding_attributes(family)
        core_finding_attributes(family)
          .merge(triage_attributes_for(family.root_kind))
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

      def ignored_declaration_name?(name)
        IGNORED_DECLARATION_NAMES.include?(name) || name.include?(SYNTHETIC_DECLARATION_MARKER)
      end
    end
  end
end
