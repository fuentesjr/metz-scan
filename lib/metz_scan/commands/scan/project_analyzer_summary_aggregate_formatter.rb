# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      class ProjectAnalyzerSummaryAggregateFormatter
        def initialize(summary)
          @summary = summary
        end

        def lines
          [counts_line("Analyzer counts", analyzer_counts),
           counts_line("Confidence counts", breakdown_counts("confidence")),
           counts_line("Severity counts", breakdown_counts("triage_severity")),
           counts_line("Category counts", category_counts)].compact
        end

        private

        attr_reader :summary

        def analyzer_counts
          rules.to_h { |rule| [rule.fetch("cop_name"), rule.fetch("finding_count").to_i] }
        end

        def breakdown_counts(key)
          counts = counts_from_rule_breakdowns(key)
          counts.empty? ? counts_from_rule_field(key) : counts
        end

        def category_counts
          counts = counts_from_rule_breakdowns("project_analyzer_category", metadata: true)
          counts.empty? ? counts_from_all_metadata_breakdowns : counts
        end

        def counts_from_rule_breakdowns(key, metadata: false)
          rules.each_with_object(Hash.new(0)) do |rule, counts|
            entries = metadata ? rule.dig("breakdowns", "metadata", key) : rule.dig("breakdowns", key)
            Array(entries).each { |entry| counts[entry.fetch("value")] += entry.fetch("finding_count").to_i }
          end
        end

        def counts_from_all_metadata_breakdowns
          rules.each_with_object(Hash.new(0)) do |rule, counts|
            rule.dig("breakdowns", "metadata").to_h.each_value do |entries|
              Array(entries).each { |entry| counts[entry.fetch("value")] += entry.fetch("finding_count").to_i }
            end
          end
        end

        def counts_from_rule_field(key)
          rules.each_with_object(Hash.new(0)) do |rule, counts|
            value = rule[key]
            counts[value] += rule.fetch("finding_count").to_i if value
          end
        end

        def counts_line(label, counts)
          return if counts.empty?

          "  #{label}: #{sorted_counts(counts).map { |value, count| "#{value}=#{count}" }.join(', ')}"
        end

        def sorted_counts(counts)
          counts.sort_by { |value, count| [-count, value.to_s] }
        end

        def rules
          @rules ||= Array(summary["rules"])
        end
      end
    end
  end
end
