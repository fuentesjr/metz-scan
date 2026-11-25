# frozen_string_literal: true

require "optparse"
require "yaml"
require_relative "../cli"

module MetzScan
  module Commands
    class Explain
      USAGE = "Usage: metz-scan explain <Metz/CopName|MetzProject/AnalyzerName>"
      NON_KNOB_KEYS = %w[Description VersionAdded StyleGuide Reference].freeze
      RULE_LIST_HINT = "Run `metz-scan rules` or `metz-scan project-analyzers` to see available rules."

      def self.run(argv, stdout:, stderr:)
        new(stdout: stdout, stderr: stderr).run(argv)
      end

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
      end

      def run(argv)
        args = parse_options(argv.dup)
        return missing_argument_error if args.empty?

        emit_or_error(args.first)
      rescue OptionParser::ParseError => e
        usage_error("metz-scan explain: #{e.message}", USAGE)
      end

      def emit_or_error(name)
        return emit_project_analyzer(name) if name.start_with?("MetzProject/")

        cop = lookup_metz_cop(name)
        cop ? emit_cop(cop) : unknown_rule_error(name)
      end

      private

      attr_reader :stdout, :stderr

      def parse_options(argv)
        OptionParser.new { |opts| opts.banner = USAGE }.parse!(argv)
        argv
      end

      def emit_project_analyzer(name)
        require_relative "scan/project_analyzer_runner"
        analyzer = Scan::ProjectAnalyzerRunner::ANALYZERS.find { |entry| name == entry::RULE_ID }
        analyzer ? emit_analyzer(analyzer) : unknown_rule_error(name)
      end

      def lookup_metz_cop(name)
        require "rubocop-metz"
        cop = RuboCop::Cop::Registry.global.find_by_cop_name(name)
        cop if cop&.cop_name&.start_with?("Metz/") && cop.respond_to?(:metz_metadata)
      end

      def missing_argument_error
        usage_error("metz-scan explain: missing required RULE_NAME argument.", USAGE, RULE_LIST_HINT)
      end

      def unknown_rule_error(name)
        usage_error("metz-scan explain: rule '#{name}' not found.", RULE_LIST_HINT)
      end

      def usage_error(*lines)
        lines.each { |line| stderr.puts line }
        CLI::USAGE_ERROR
      end

      def emit_cop(cop)
        emit_sections(cop.cop_name, cop.why_it_matters, cop.fix_safety, cop.suggested_next_moves)
        emit_configuration(cop.cop_name)
        0
      end

      def emit_analyzer(analyzer)
        emit_sections(analyzer::RULE_ID, analyzer::WHY, "manual", analyzer::SUGGESTED_NEXT_MOVES)
        emit_analyzer_status(analyzer)
        0
      end

      def emit_sections(title, why, safety, moves)
        stdout.puts title, "=" * title.length, "", "Why it matters:", "  #{why}", ""
        stdout.puts "Fix safety: #{safety}", ""
        emit_suggested_next_moves(moves)
      end

      def emit_suggested_next_moves(moves)
        stdout.puts "Suggested next moves:"
        moves.each { |move| stdout.puts "  - #{move}" }
        stdout.puts
      end

      def emit_analyzer_status(analyzer)
        default_scan = Scan::ProjectAnalyzerRunner.default_output_analyzer?(analyzer) ? "yes" : "no"
        stdout.puts "Status: #{analyzer::PROJECT_ANALYZER_STATUS}", "Default scan: #{default_scan}"
        stdout.puts "Confidence: #{analyzer::CONFIDENCE}", "Triage: #{analyzer::TRIAGE_SEVERITY}"
      end

      def emit_configuration(cop_name)
        knobs = (default_config[cop_name] || {}).except(*NON_KNOB_KEYS)
        return if knobs.empty?

        stdout.puts "Configuration:"
        knobs.each { |key, value| stdout.puts "  #{key}: #{format_value(value)}" }
      end

      def default_config
        @default_config ||= YAML.load_file(RuboCop::Metz::Plugin.new.rules(nil).value.to_s)
      end

      def format_value(value)
        return value.to_s unless value.is_a?(Array)

        value.empty? ? "[]" : value.join(", ")
      end
    end
  end
end
