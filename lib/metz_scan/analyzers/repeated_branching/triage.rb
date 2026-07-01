# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedBranching
      module Triage
        GENERIC_CONFIDENCE = "low"
        GENERIC_TRIAGE_SEVERITY = "context required"
        GENERIC_TRIAGE_SUMMARY = "Generic repeated-decision signal; use reported contexts and branch values before " \
                                 "treating this as design pressure."
        private_constant :GENERIC_CONFIDENCE, :GENERIC_TRIAGE_SEVERITY, :GENERIC_TRIAGE_SUMMARY

        module_function

        def attributes_for(subject, status:, fallback:)
          return fallback unless subject.generic?

          generic_subject_attributes(status)
        end

        def generic_subject_attributes(status)
          { project_analyzer_status: status, confidence: GENERIC_CONFIDENCE,
            triage_severity: GENERIC_TRIAGE_SEVERITY, triage_summary: GENERIC_TRIAGE_SUMMARY }
        end
      end
    end
  end
end
