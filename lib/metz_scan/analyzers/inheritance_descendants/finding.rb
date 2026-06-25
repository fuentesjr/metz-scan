# frozen_string_literal: true

module MetzScan
  module Analyzers
    class InheritanceDescendants
      Finding = Struct.new(:source, :rule_id, :message, :base_name, :descendants, :locations, :primary_location,
                           :why_it_matters, :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :suggested_next_moves, keyword_init: true) do
        def occurrences = [primary_location].compact

        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: base_name) }
        end
      end
      Location = Struct.new(:name, :path, keyword_init: true)
    end
  end
end
