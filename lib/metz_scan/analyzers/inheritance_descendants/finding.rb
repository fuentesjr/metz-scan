# frozen_string_literal: true

require_relative "../finding"

module MetzScan
  module Analyzers
    class InheritanceDescendants
      Finding = Analyzers::Finding.define(:base_name, :descendants, :locations, :primary_location) do
        def occurrences = [primary_location].compact

        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: base_name) }
        end
      end
      Location = Struct.new(:name, :path, keyword_init: true)
    end
  end
end
