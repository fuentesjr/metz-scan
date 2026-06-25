# frozen_string_literal: true

require_relative "../project_index"
require_relative "inheritance_descendants/finding"
require_relative "inheritance_descendants/root_kind"
require_relative "occurrence"

module MetzScan
  module Analyzers
    # Reports configured inheritance roots with enough known descendants.
    class InheritanceDescendants
      RULE_ID = "MetzProject/DeepInheritanceTree"
      PROJECT_ANALYZER_STATUS = "experimental"
      CONFIDENCE = "early"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Experimental inheritance signal; review broad base classes and descendant spread in context."
      WHY = "Large inheritance trees hide coupling and make changes expensive."
      SUGGESTED_NEXT_MOVES = [
        "Review whether the base class is carrying multiple responsibilities.",
        "Prefer composition or narrower shared modules when descendants only need part of the base behavior."
      ].freeze
      IGNORED_DECLARATION_NAMES = %w[BasicObject Class Kernel Module Object].freeze
      SYNTHETIC_DECLARATION_MARKER = "::<"
      private_constant :IGNORED_DECLARATION_NAMES, :SYNTHETIC_DECLARATION_MARKER

      def initialize(paths: nil, index: nil, base_names: nil, minimum_descendants: 3)
        @paths = Array(paths)
        @index = index || ProjectIndex.build(@paths)
        @base_names = Array(base_names).compact
        @minimum_descendants = minimum_descendants
      end

      def call
        return [] unless index.available?

        base_candidates.filter_map { |base_name| finding_for(base_name) }
      end

      private

      attr_reader :paths, :index, :base_names, :minimum_descendants

      def base_candidates
        return base_names unless base_names.empty?

        auto_discovered_base_candidates
      end

      def auto_discovered_base_candidates
        index.declarations.select { |declaration| auto_discovered_base_candidate?(declaration) }
                          .map(&:name).compact.uniq.sort
      end

      def auto_discovered_base_candidate?(declaration)
        declaration.name && declaration.path && class_candidate?(declaration) &&
          !ignored_declaration_name?(declaration.name)
      end

      def class_candidate?(declaration)
        !declaration.respond_to?(:kind) || declaration.kind.nil? || declaration.kind == :class
      end

      def finding_for(base_name)
        descendants = sorted_descendants(base_name)
        return if descendants.size < minimum_descendants

        build_finding(base_name, descendants)
      end

      def sorted_descendants(base_name)
        index.descendants_of(base_name).reject { |name| ignored_declaration_name?(name) }.sort
      end

      def build_finding(base_name, descendants)
        descendant_locations = locations_for(descendants)
        Finding.new(finding_attributes(base_name, descendants, descendant_locations))
      end

      def finding_attributes(base_name, descendants, descendant_locations)
        root_kind = RootKind.for(base_name)
        core_finding_attributes(base_name, descendants, descendant_locations, root_kind)
          .merge(triage_for(base_name, descendants, descendant_locations, root_kind))
      end

      def core_finding_attributes(base_name, descendants, descendant_locations, root_kind)
        { source: index.backend_name.to_s, rule_id: RULE_ID, message: message_for(base_name, descendants, root_kind),
          base_name: base_name, descendants: descendants, locations: descendant_locations,
          primary_location: primary_location_for(base_name, descendant_locations), why_it_matters: WHY,
          suggested_next_moves: SUGGESTED_NEXT_MOVES }
      end

      def triage_for(base_name, descendants, descendant_locations, root_kind)
        { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: CONFIDENCE,
          triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY,
          project_analyzer_metadata: project_analyzer_metadata_for(base_name, descendants, descendant_locations,
                                                                   root_kind) }
      end

      def message_for(base_name, descendants, root_kind)
        label = root_kind ? " (#{root_kind})" : ""
        "#{base_name}#{label} has #{descendants.size} descendants; " \
          "consider whether shared behavior is becoming too broad."
      end

      def locations_for(descendants)
        descendants.filter_map { |name| location_for(name) }
      end

      def primary_location_for(base_name, descendant_locations)
        location_for(base_name) || descendant_locations.first
      end

      def project_analyzer_metadata_for(base_name, descendants, descendant_locations, root_kind)
        { "base_name" => base_name, "descendants" => descendants,
          "descendant_count" => descendants.size, "descendant_locations" => location_metadata(descendant_locations),
          "root_kind" => root_kind, "source" => index.backend_name.to_s }.compact
      end

      def location_metadata(locations)
        locations.map { |location| { "name" => location.name, "path" => location.path } }
      end

      def location_for(name)
        declaration = declarations_by_name[name]
        Location.new(name: name, path: declaration.path) if declaration&.path
      end

      def declarations_by_name
        @declarations_by_name ||= index.declarations.to_h { |declaration| [declaration.name, declaration] }
      end

      def ignored_declaration_name?(name)
        IGNORED_DECLARATION_NAMES.include?(name) || name.include?(SYNTHETIC_DECLARATION_MARKER)
      end
    end
  end
end
