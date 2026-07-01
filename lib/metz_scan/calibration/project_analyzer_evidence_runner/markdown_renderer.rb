# frozen_string_literal: true

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class MarkdownRenderer
        def initialize(summary)
          @summary = summary
        end

        def call
          "#{sections.join("\n")}\n"
        end

        private

        attr_reader :summary

        def sections
          [header_section, target_section, rule_section, breakdown_section].flatten
        end

        def header_section
          ["# Project analyzer evidence", "", *header_metadata_lines, "", *header_count_lines, ""]
        end

        def header_metadata_lines
          ["Generated: #{summary.fetch('generated_at')}",
           "Default output filter: #{summary.fetch('default_output')}",
           "Analyzer filter: #{analyzer_filter_label}", *targets_file_lines,
           "Fixture root: `#{summary.fetch('fixture_root')}`"]
        end

        def header_count_lines
          ["Findings: #{summary.fetch('finding_count')}", "Offenses: #{summary.fetch('offense_count')}"]
        end

        def analyzer_filter_label
          analyzer_names = summary.fetch("analyzer_filter", [])
          analyzer_names.empty? ? "none" : analyzer_names.join(", ")
        end

        def targets_file_lines
          targets_file = summary["targets_file"]
          targets_file ? ["Targets file: `#{targets_file}`"] : []
        end

        def target_section
          ["## Targets", "", target_header, *target_rows, ""]
        end

        def target_header
          "| Target | Revision | Scan paths | Backend | Findings | Offenses |\n" \
            "| --- | --- | --- | --- | ---: | ---: |"
        end

        def target_rows
          summary.fetch("targets").map { |target| target_row(target) }
        end

        def target_row(target)
          "| #{target.fetch('name')} | #{revision_label(target)} | #{scan_paths_label(target)} | " \
            "#{target.fetch('index').fetch('backend')} | #{target.fetch('finding_count')} | " \
            "#{target.fetch('offense_count')} |"
        end

        def revision_label(target)
          target.fetch("git").fetch("revision", "unknown")[0, 12]
        end

        def scan_paths_label(target)
          target.fetch("scan_paths").map { |path| "`#{path}`" }.join("<br>")
        end

        def rule_section
          rules = summary.fetch("project_analyzers").fetch("rules", [])
          return ["## Rules", "", "No project-analyzer findings."] if rules.empty?

          ["## Rules", "", rule_header, *rule_rows(rules)]
        end

        def rule_header
          "| Rule | Findings | Offenses | Status | Confidence | Severity |\n" \
            "| --- | ---: | ---: | --- | --- | --- |"
        end

        def rule_rows(rules)
          rules.map { |rule| rule_row(rule) }
        end

        def rule_row(rule)
          "| #{rule.fetch('cop_name')} | #{rule.fetch('finding_count')} | #{rule.fetch('offense_count')} | " \
            "#{rule.fetch('status', '?')} | #{rule.fetch('confidence', '?')} | " \
            "#{rule.fetch('triage_severity', '?')} |"
        end

        def breakdown_section
          breakdowns = summary.fetch("breakdowns", {})
          return [] if breakdowns.empty?

          ["", "## Breakdowns", "", *breakdown_subsections(breakdowns)]
        end

        def breakdown_subsections(breakdowns)
          [breakdown_table("Confidence", breakdowns["confidence"]),
           breakdown_table("Severity", breakdowns["triage_severity"]),
           *metadata_breakdown_tables(breakdowns.fetch("metadata", {}))].compact
        end

        def metadata_breakdown_tables(metadata)
          metadata.map { |key, values| breakdown_table("Metadata: `#{key}`", values) }
        end

        def breakdown_table(title, values)
          return if values.to_a.empty?

          ["### #{title}", "", "| Value | Findings |", "| --- | ---: |",
           *values.map { |value| breakdown_row(value) }, ""]
        end

        def breakdown_row(value)
          "| #{value.fetch('value')} | #{value.fetch('finding_count')} |"
        end
      end
    end
  end
end
