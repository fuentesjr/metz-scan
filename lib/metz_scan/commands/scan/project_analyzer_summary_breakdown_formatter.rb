# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      class ProjectAnalyzerSummaryBreakdownFormatter
        def initialize(rule)
          @rule = rule
        end

        def call
          return if segments.empty?

          "mix: #{segments.join('; ')}"
        end

        private

        attr_reader :rule

        def segments
          [mixed_segment("severity", breakdowns["triage_severity"]),
           *metadata_segments].compact
        end

        def breakdowns
          rule.fetch("breakdowns", {})
        end

        def metadata_segments
          breakdowns.fetch("metadata", {}).map { |key, values| mixed_segment(key, values) }
        end

        def mixed_segment(label, values)
          return unless values.to_a.size > 1

          "#{label} #{values.map { |value| label_for(value) }.join(', ')}"
        end

        def label_for(value)
          "#{value.fetch('value')}=#{value.fetch('finding_count')}"
        end
      end
    end
  end
end
