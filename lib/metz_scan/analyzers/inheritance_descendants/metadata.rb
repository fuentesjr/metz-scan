# frozen_string_literal: true

module MetzScan
  module Analyzers
    class InheritanceDescendants
      module Metadata
        module_function

        def for(base_name, descendants, descendant_locations, context)
          { "base_name" => base_name, "descendants" => descendants,
            "descendant_count" => descendants.size,
            "descendant_locations" => location_metadata(descendant_locations),
            "root_kind" => context.fetch(:root_kind), "source" => context.fetch(:source) }.compact
        end

        def location_metadata(locations)
          locations.map { |location| { "name" => location.name, "path" => location.path } }
        end
      end
    end
  end
end
