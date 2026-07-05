# frozen_string_literal: true

require "json"

module MetzScan
  module Calibration
    class RubydexDriftFormatter
      def initialize(summary, analyzers:)
        @summary = summary
        @analyzers = analyzers
      end

      def json
        JSON.pretty_generate(payload)
      end

      def text
        [header_lines, rule_lines, breakdown_lines].flatten.compact.join("\n")
      end

      private

      attr_reader :summary, :analyzers

      def payload
        compact_identity.merge(compact_results)
      end

      def compact_identity
        { "targets_file" => summary["targets_file"],
          "targets" => target_names,
          "analyzers" => analyzers }.compact
      end

      def compact_results
        { "finding_count" => summary.fetch("finding_count"),
          "offense_count" => summary.fetch("offense_count"),
          "rules" => rules,
          "breakdowns" => summary.fetch("breakdowns", {}) }
      end

      def header_lines
        ["rubydex drift check",
         targets_file_line,
         "targets: #{target_names.join(', ')}",
         "analyzers: #{analyzers.join(', ')}",
         "findings: #{summary.fetch('finding_count')} (offenses: #{summary.fetch('offense_count')})"]
      end

      def target_names
        summary.fetch("targets").map { |target| target.fetch("name") }
      end

      def targets_file_line
        "targets file: #{summary['targets_file']}" if summary["targets_file"]
      end

      def rule_lines
        return ["rules: none"] if rules.empty?

        ["rules:", *rules.map { |rule| rule_line(rule) }]
      end

      def rules
        summary.fetch("project_analyzers", {}).fetch("rules", [])
      end

      def rule_line(rule)
        "  - #{rule.fetch('cop_name')}: #{rule.fetch('finding_count')} finding(s), " \
          "#{rule.fetch('offense_count')} offense(s), status=#{rule.fetch('status', '?')}, " \
          "confidence=#{rule.fetch('confidence', '?')}, severity=#{rule.fetch('triage_severity', '?')}"
      end

      def breakdown_lines
        lines = [breakdown_line("confidence", breakdowns["confidence"]),
                 breakdown_line("severity", breakdowns["triage_severity"])].compact
        lines.empty? ? [] : ["breakdowns:", *lines]
      end

      def breakdowns
        summary.fetch("breakdowns", {})
      end

      def breakdown_line(label, values)
        return if values.to_a.empty?

        "  - #{label}: #{values.map { |value| "#{value.fetch('value')}=#{value.fetch('finding_count')}" }.join(', ')}"
      end
    end
  end
end
