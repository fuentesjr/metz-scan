# frozen_string_literal: true

module MetzScan
  module Analyzers
    class InheritanceDescendants
      module Triage
        BROAD_ROOT_CONFIDENCE = "low"
        BROAD_ROOT_TRIAGE_SEVERITY = "broad base"
        BROAD_ROOT_TRIAGE_SUMMARY = "Broad inheritance base; review only when shared behavior changes often " \
                                    "or descendants diverge."

        module_function

        def attributes_for(root_kind)
          root_kind ? broad_root_attributes : candidate_attributes
        end

        def candidate_attributes
          { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: CONFIDENCE,
            triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
        end

        def broad_root_attributes
          { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: BROAD_ROOT_CONFIDENCE,
            triage_severity: BROAD_ROOT_TRIAGE_SEVERITY, triage_summary: BROAD_ROOT_TRIAGE_SUMMARY }
        end
      end
    end
  end
end
