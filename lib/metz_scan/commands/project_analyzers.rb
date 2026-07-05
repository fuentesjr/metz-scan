# frozen_string_literal: true

require "json"
require "optparse"

require_relative "scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ProjectAnalyzers
      USAGE = "Usage: metz-scan project-analyzers [--json]"

      def self.run(argv, stdout:, stderr:)
        new(stdout: stdout, stderr: stderr).run(argv)
      end

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
      end

      def run(argv)
        options = parse_options(argv)
        return 1 unless options

        entries = analyzer_entries
        options[:json] ? emit_json(entries) : emit_table(entries)
        0
      end

      private

      attr_reader :stdout, :stderr

      def parse_options(argv)
        options = { json: false }
        OptionParser.new { |opts| configure_options(opts, options) }.parse!(argv)
        options
      rescue OptionParser::ParseError => e
        parse_error(e)
      end

      def parse_error(error)
        stderr.puts error.message
        stderr.puts option_parser.help
        nil
      end

      def configure_options(opts, options)
        opts.banner = USAGE
        opts.on("--json", "Emit a JSON array of project analyzers") { options[:json] = true }
      end

      def option_parser
        OptionParser.new { |opts| configure_options(opts, {}) }
      end

      def analyzer_entries
        Scan::ProjectAnalyzerRunner::ANALYZERS.map { |analyzer| analyzer_entry(analyzer) }
      end

      def analyzer_entry(analyzer)
        { name: analyzer::RULE_ID, status: analyzer::PROJECT_ANALYZER_STATUS,
          default_output: Scan::ProjectAnalyzerRunner.default_output_analyzer?(analyzer),
          confidence: analyzer::CONFIDENCE, triage_severity: analyzer::TRIAGE_SEVERITY,
          triage_summary: analyzer::TRIAGE_SUMMARY, why_it_matters: analyzer::WHY,
          suggested_next_moves: analyzer::SUGGESTED_NEXT_MOVES }
      end

      def emit_json(entries)
        stdout.puts JSON.generate(entries)
      end

      def emit_table(entries)
        widths = column_widths(entries)
        stdout.puts row(%w[ANALYZER STATUS DEFAULT CONFIDENCE TRIAGE], widths)
        stdout.puts row(widths.map { |_key, width| "-" * width }, widths)
        entries.each { |entry| stdout.puts entry_row(entry, widths) }
      end

      def column_widths(entries)
        { name: max_width(entries, :name, "ANALYZER"), status: max_width(entries, :status, "STATUS"),
          default: "DEFAULT".length, confidence: max_width(entries, :confidence, "CONFIDENCE"),
          triage: max_width(entries, :triage_severity, "TRIAGE") }
      end

      def max_width(entries, key, header)
        [header.length, entries.map { |entry| entry.fetch(key).length }.max].max
      end

      def entry_row(entry, widths)
        row([entry.fetch(:name), entry.fetch(:status), default_label(entry),
             entry.fetch(:confidence), entry.fetch(:triage_severity)], widths)
      end

      def default_label(entry)
        entry.fetch(:default_output) ? "yes" : "no"
      end

      def row(values, widths)
        values.zip(widths.values).map { |value, width| format("%-#{width}s", value) }.join("  ").rstrip
      end
    end
  end
end
