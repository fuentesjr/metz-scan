# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      module ProjectAnalyzerTriageFormatter
        module_function

        def line(metadata)
          return unless metadata

          line_for(triage_details(metadata), metadata["triage_summary"])
        end

        def line_for(details, summary)
          return unless details.any? || !blank?(summary)
          return summary.to_s if details.empty?

          ["Triage: #{details.join('; ')}.", summary].compact.join(" ")
        end

        def triage_details(metadata)
          [
            labeled("status", metadata["status"]),
            labeled("confidence", metadata["confidence"]),
            labeled("severity", metadata["triage_severity"])
          ].compact
        end

        def labeled(name, value)
          "#{name}: #{value}" unless blank?(value)
        end

        def blank?(value)
          value.nil? || value.to_s.empty?
        end
      end
    end
  end
end
