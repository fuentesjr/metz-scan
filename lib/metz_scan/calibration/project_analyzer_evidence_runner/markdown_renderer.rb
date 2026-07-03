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
          section_renderers.flat_map { |renderer| renderer.new(summary).call }
        end

        def section_renderers
          [HeaderMarkdown, TargetsMarkdown, RulesMarkdown, ReadinessMarkdown,
           NotableFindingsMarkdown, BreakdownsMarkdown]
        end
      end

      module MarkdownTableCells
        private

        def cell(value)
          value.to_s.gsub("|", "\\|")
        end
      end

      class HeaderMarkdown
        def initialize(summary)
          @summary = summary
        end

        def call
          ["# Project analyzer evidence", "", *metadata_lines, "", *count_lines, ""]
        end

        private

        attr_reader :summary

        def metadata_lines
          ["Generated: #{summary.fetch('generated_at')}",
           "Default output filter: #{summary.fetch('default_output')}",
           "Analyzer filter: #{analyzer_filter_label}", *targets_file_lines,
           "Fixture root: `#{summary.fetch('fixture_root')}`"]
        end

        def count_lines
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
      end

      class TargetsMarkdown
        def initialize(summary)
          @summary = summary
        end

        def call
          ["## Targets", "", header, *rows, ""]
        end

        private

        attr_reader :summary

        def header
          "| Target | Revision | Scan paths | Backend | Findings | Offenses |\n" \
            "| --- | --- | --- | --- | ---: | ---: |"
        end

        def rows
          summary.fetch("targets").map { |target| row(target) }
        end

        def row(target)
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
      end

      class RulesMarkdown
        def initialize(summary)
          @summary = summary
        end

        def call
          return ["## Rules", "", "No project-analyzer findings."] if rules.empty?

          ["## Rules", "", header, *rows]
        end

        private

        attr_reader :summary

        def rules
          summary.fetch("project_analyzers").fetch("rules", [])
        end

        def header
          "| Rule | Findings | Offenses | Status | Confidence | Severity |\n" \
            "| --- | ---: | ---: | --- | --- | --- |"
        end

        def rows
          rules.map { |rule| row(rule) }
        end

        def row(rule)
          "| #{rule.fetch('cop_name')} | #{rule.fetch('finding_count')} | #{rule.fetch('offense_count')} | " \
            "#{rule.fetch('status', '?')} | #{rule.fetch('confidence', '?')} | " \
            "#{rule.fetch('triage_severity', '?')} |"
        end
      end

      class ReadinessMarkdown
        include MarkdownTableCells

        def initialize(summary)
          @summary = summary
        end

        def call
          return [] if readiness.empty?

          ["", "## Readiness", "", header, *rows, ""]
        end

        private

        attr_reader :summary

        def readiness
          summary.fetch("project_analyzers").fetch("readiness", [])
        end

        def header
          "| Rule | Disposition | Evidence | Next | Not next |\n" \
            "| --- | --- | --- | --- | --- |"
        end

        def rows
          readiness.map { |entry| row(entry) }
        end

        def row(entry)
          "| #{cell(entry.fetch('rule_id'))} | #{cell(entry.fetch('disposition'))} | " \
            "#{cell(entry.fetch('evidence'))} | #{cell(entry.fetch('next'))} | " \
            "#{cell(entry.fetch('not_next'))} |"
        end
      end

      class NotableFindingsMarkdown
        include MarkdownTableCells

        def initialize(summary)
          @notable_findings = summary.fetch("notable_findings", [])
        end

        def call
          return [] if notable_findings.empty?

          ["", "## Notable Findings", "", header, *rows, ""]
        end

        private

        attr_reader :notable_findings

        def header
          "| Target | Rule | Confidence | Severity | Category | Location | Message |\n" \
            "| --- | --- | --- | --- | --- | --- | --- |"
        end

        def rows
          notable_findings.map { |finding| row(finding) }
        end

        def row(finding)
          "| #{cell(finding.fetch('target'))} | #{cell(finding.fetch('rule_id'))} | " \
            "#{cell(finding.fetch('confidence', '?'))} | #{cell(finding.fetch('triage_severity', '?'))} | " \
            "#{cell(finding.fetch('category', '?'))} | #{cell(location_label(finding))} | " \
            "#{cell(finding.fetch('message'))} |"
        end

        def location_label(finding)
          occurrence = finding.fetch("occurrence", {})
          [occurrence["path"], occurrence["line"]].compact.join(":")
        end
      end

      class BreakdownsMarkdown
        def initialize(summary)
          @breakdowns = summary.fetch("breakdowns", {})
        end

        def call
          return [] if breakdowns.empty?

          ["", "## Breakdowns", "", *subsections.flatten]
        end

        private

        attr_reader :breakdowns

        def subsections
          [table("Confidence", breakdowns["confidence"]),
           table("Severity", breakdowns["triage_severity"]),
           *metadata_tables].compact
        end

        def metadata_tables
          breakdowns.fetch("metadata", {}).map { |key, values| table("Metadata: `#{key}`", values) }
        end

        def table(title, values)
          return if values.to_a.empty?

          ["### #{title}", "", "| Value | Findings |", "| --- | ---: |",
           *values.map { |value| row(value) }, ""]
        end

        def row(value)
          "| #{value.fetch('value')} | #{value.fetch('finding_count')} |"
        end
      end

      private_constant :MarkdownTableCells, :HeaderMarkdown, :TargetsMarkdown, :RulesMarkdown
      private_constant :ReadinessMarkdown, :NotableFindingsMarkdown, :BreakdownsMarkdown
    end
  end
end
