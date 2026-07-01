# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      module ProjectAnalyzerTriagePriority
        PRIORITIES = {
          "status" => { "validated" => 0, "candidate" => 1, "experimental" => 2 },
          "confidence" => { "high" => 0, "medium" => 1, "early" => 2, "low" => 3 },
          "triage_severity" => {
            "design pressure" => 0,
            "manual review" => 1,
            "context required" => 2,
            "broad base" => 3,
            "shared dependency" => 4,
            "shared namespace" => 5,
            "setup orchestration" => 6
          }
        }.freeze

        module_function

        def sort_key(metadata)
          [
            priority_for("status", metadata["status"]),
            priority_for("confidence", metadata["confidence"]),
            priority_for("triage_severity", metadata["triage_severity"])
          ]
        end

        def priority_for(name, value)
          priorities = PRIORITIES.fetch(name)
          priorities.fetch(value, priorities.size)
        end
      end
    end
  end
end
