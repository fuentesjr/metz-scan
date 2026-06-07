# frozen_string_literal: true

require_relative "../project_index"

module MetzScan
  module Analyzers
    # Reports configured inheritance roots with enough known descendants.
    class InheritanceDescendants
      RULE_ID = "MetzProject/DeepInheritanceTree"
      WHY = "Large inheritance trees hide coupling and make changes expensive."
      SUGGESTED_NEXT_MOVES = [
        "Review whether the base class is carrying multiple responsibilities.",
        "Prefer composition or narrower shared modules when descendants only need part of the base behavior."
      ].freeze

      Finding = Struct.new(:source, :rule_id, :message, :base_name, :descendants, :locations, :why_it_matters,
                           :suggested_next_moves, keyword_init: true)
      Location = Struct.new(:name, :path, keyword_init: true)

      def initialize(index:, base_names:, minimum_descendants: 1)
        @index = index
        @base_names = Array(base_names)
        @minimum_descendants = minimum_descendants
      end

      def call
        return [] unless index.available?

        base_names.filter_map { |base_name| finding_for(base_name) }
      end

      private

      attr_reader :index, :base_names, :minimum_descendants

      def finding_for(base_name)
        descendants = sorted_descendants(base_name)
        return if descendants.size < minimum_descendants

        build_finding(base_name, descendants)
      end

      def sorted_descendants(base_name)
        index.descendants_of(base_name).sort
      end

      def build_finding(base_name, descendants)
        Finding.new(source: index.backend_name.to_s, rule_id: RULE_ID, message: message_for(base_name, descendants),
                    base_name: base_name, descendants: descendants, locations: locations_for(descendants),
                    why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES)
      end

      def message_for(base_name, descendants)
        "#{base_name} has #{descendants.size} descendants; consider whether shared behavior is becoming too broad."
      end

      def locations_for(descendants)
        descendants.filter_map { |name| location_for(name) }
      end

      def location_for(name)
        declaration = declarations_by_name[name]
        Location.new(name: name, path: declaration.path) if declaration&.path
      end

      def declarations_by_name
        @declarations_by_name ||= index.declarations.to_h { |declaration| [declaration.name, declaration] }
      end
    end
  end
end
