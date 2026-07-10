# frozen_string_literal: true

require_relative "../occurrence"

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      Finding = Struct.new(:source, :rule_id, :message, :path, :line, :owner_name, :method_name,
                           :method_identity, :receiver_kind, :visibility, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true) do
        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: occurrence_context) }.compact
        end

        def occurrence_context
          "#{owner_name}#{receiver_kind == 'singleton' ? '.' : '#'}#{method_name}"
        end
      end
    end
  end
end
