# frozen_string_literal: true

require_relative "../occurrence"

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      Finding = Struct.new(:source, :rule_id, :message, :base_name, :method_name, :method_identity,
                           :receiver_kind, :descendant_count, :overriding_descendants, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata,
                           :why_it_matters, :suggested_next_moves, keyword_init: true) do
        def report_occurrences
          occurrence = occurrences.first
          [Occurrence.from(occurrence, context: occurrence_context(occurrence))].compact
        end

        def occurrence_context(occurrence)
          "#{occurrence&.owner_name}#{method_separator(occurrence)}#{method_name}"
        end

        def method_separator(occurrence)
          return "#" unless occurrence.respond_to?(:receiver_kind)

          occurrence.receiver_kind == "singleton" ? "." : "#"
        end
      end
    end
  end
end
