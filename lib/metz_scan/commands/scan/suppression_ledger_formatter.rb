# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      class SuppressionLedgerFormatter
        def initialize(parsed)
          @records = Array(parsed["suppressions"])
        end

        def lines
          return [] if records.empty?

          [heading, *records.flat_map { |record| record_lines(record) }, ""]
        end

        private

        attr_reader :records

        def heading
          missing = records.count { |record| record.fetch("reason_status") == "missing" }
          "Suppressed findings: #{records.size}, #{missing} without a reason"
        end

        def record_lines(record)
          ["  #{record.fetch('path')}:#{record.fetch('line')}:#{record.fetch('column')} #{record.fetch('message')}",
           "    #{source(record)}, #{reason(record)}"]
        end

        def source(record)
          return "inline disable at line #{record.dig('directive', 'line')}" unless record.fetch("config")

          config = record.fetch("config")
          "#{[config.fetch('path'), config.fetch('line')].compact.join(':')} #{config_setting(record)}"
        end

        def config_setting(record)
          return "Enabled: false" if record.fetch("suppressed_by") == "config_disabled"

          "Exclude \"#{record.dig('config', 'pattern')}\""
        end

        def reason(record)
          case record.fetch("reason_status")
          when "present" then "reason: #{record.fetch('reason')}"
          when "missing" then "no reason"
          else "reason not checked"
          end
        end
      end
    end
  end
end
