# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      class Namespace
        def initialize(name)
          @segments = name.to_s.split("::")
        end

        attr_reader :segments

        def deep?
          segments.size >= 3
        end

        def home_name
          home_segments.join("::")
        end

        def home_path_parts
          home_segments.map { |part| underscore(part) }
        end

        private

        def home_segments
          segments[0...-1]
        end

        def underscore(value)
          value.to_s
               .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
               .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
               .tr("-", "_")
               .downcase
        end
      end
    end
  end
end
