# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      module SarifSeverity
        LEVEL_BY_SEVERITY = {
          "error" => "error", "fatal" => "error",
          "warning" => "warning", "convention" => "warning", "refactor" => "warning",
          "info" => "note", "information" => "note"
        }.freeze
        LEVEL_RANK = { "note" => 0, "warning" => 1, "error" => 2 }.freeze

        module_function

        def level_for(severity)
          LEVEL_BY_SEVERITY.fetch(severity.to_s, "warning")
        end

        def highest_level(severities)
          severities.map { |severity| level_for(severity) }
                    .max_by { |level| LEVEL_RANK.fetch(level, 1) }
        end
      end
    end
  end
end
