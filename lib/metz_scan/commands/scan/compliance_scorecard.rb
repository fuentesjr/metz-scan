# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      class ComplianceScorecard
        RULE_COP_PREFIX = "Metz/"
        TOP_FILE_LIMIT = 5

        def self.add_to_summary!(parsed)
          new(parsed).add_to_summary!
        end

        def initialize(parsed)
          @parsed = parsed
        end

        def add_to_summary!
          writable_summary["clean_file_count"] = clean_file_count
          writable_summary["files_with_offenses"] = files_with_rule_offenses
          writable_summary["offenses_by_cop"] = offenses_by_cop
          parsed
        end

        def lines
          ["Summary", "-------", compliance_line, *offense_summary_lines]
        end

        private

        attr_reader :parsed

        def offense_summary_lines
          return ["No offenses found."] if offense_count.zero?

          [offense_total_line, "", "By cop:", *formatted_rows(sorted_cop_counts), "",
           "Most offenses:", *formatted_rows(top_file_counts)]
        end

        def compliance_line
          return "Metz compliance: n/a (no files scanned)" if inspected_file_count.zero?

          "Metz compliance: #{compliance_percentage}% (#{clean_file_count}/#{inspected_file_count} files clean)"
        end

        def compliance_percentage
          ((clean_file_count.to_f / inspected_file_count) * 100).round
        end

        def clean_file_count
          inspected_file_count - files_with_rule_offenses
        end

        def files_with_rule_offenses
          files.count { |file| rule_offenses?(file) }
        end

        def rule_offenses?(file)
          Array(file["offenses"]).any? { |offense| offense.fetch("cop_name").start_with?(RULE_COP_PREFIX) }
        end

        def offense_total_line
          "#{count_label(offense_count, 'offense')} across #{count_label(sorted_cop_counts.size, 'cop')}"
        end

        def offense_count
          offenses_by_cop.values.sum
        end

        def offenses_by_cop
          @offenses_by_cop ||= sorted_cop_counts.to_h
        end

        def sorted_cop_counts
          @sorted_cop_counts ||= cop_counts.sort_by { |cop_name, count| [-count, cop_name] }
        end

        def cop_counts
          offenses.each_with_object(Hash.new(0)) { |offense, counts| counts[offense.fetch("cop_name")] += 1 }
        end

        def top_file_counts
          file_counts.sort_by { |path, count| [-count, path] }.first(TOP_FILE_LIMIT)
        end

        def file_counts
          files.filter_map do |file|
            count = Array(file["offenses"]).size
            [file.fetch("path"), count] if count.positive?
          end
        end

        def formatted_rows(rows)
          width = rows.map { |label, _count| label.length }.max
          rows.map { |label, count| "  #{label.ljust(width)}  #{count}" }
        end

        def count_label(count, noun)
          "#{count} #{noun}#{'s' unless count == 1}"
        end

        def offenses
          @offenses ||= files.flat_map { |file| Array(file["offenses"]) }
        end

        def files
          @files ||= Array(parsed["files"])
        end

        def inspected_file_count
          @inspected_file_count ||= summary.fetch("inspected_file_count", files.size).to_i
        end

        def summary
          @summary ||= parsed.fetch("summary", {}) || {}
        end

        def writable_summary
          parsed["summary"] ||= {}
        end
      end
    end
  end
end
