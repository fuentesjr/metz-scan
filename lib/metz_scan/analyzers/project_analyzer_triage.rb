# frozen_string_literal: true

module MetzScan
  module Analyzers
    module ProjectAnalyzerTriage
      private

      def project_analyzer_triage_attributes
        { project_analyzer_status: self.class::PROJECT_ANALYZER_STATUS,
          confidence: self.class::CONFIDENCE,
          triage_severity: self.class::TRIAGE_SEVERITY,
          triage_summary: self.class::TRIAGE_SUMMARY }
      end

      def source_name
        index ? index.backend_name.to_s : "paths"
      end
    end
  end
end
