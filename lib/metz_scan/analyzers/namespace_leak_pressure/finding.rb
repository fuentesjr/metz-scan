# frozen_string_literal: true

require_relative "../occurrence"

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      Finding = Struct.new(:source, :rule_id, :message, :declaration_name, :home_namespace,
                           :declared_package, :referring_files, :referring_packages, :references,
                           :primary_location, :why_it_matters, :project_analyzer_status, :confidence,
                           :triage_severity, :triage_summary, :project_analyzer_metadata,
                           :suggested_next_moves, keyword_init: true) do
        def report_occurrences
          [Occurrence.from(primary_location, context: declaration_name)].compact
        end
      end
      Location = Struct.new(:name, :path, keyword_init: true)
    end
  end
end
