# frozen_string_literal: true

require_relative "offense_extractor"
require_relative "project_analyzer_triage_formatter"

module MetzScan
  module Commands
    class Scan
      class TextRenderer
        ANSI_RESET = "\e[0m"
        ANSI_BOLD = "\e[1m"
        ANSI_CYAN = "\e[36m"

        def initialize(stdout, parsed)
          @stdout = stdout
          @parsed = parsed
        end

        def render
          emit_project_analyzer_summary
          OffenseExtractor.offenses(@parsed).group_by { |o| o[:cop_name] }.sort.each do |cop_name, list|
            render_block(cop_name, list)
          end
        end

        private

        attr_reader :stdout, :parsed

        def render_block(cop_name, list)
          stdout.puts heading(cop_name)
          emit_block_metadata(cop_name, list.first)
          emit_offense_lines(list)
          stdout.puts
        end

        def emit_project_analyzer_summary
          summary = parsed.dig("summary", "project_analyzers")
          return unless summary

          emit_project_analyzer_summary_heading(summary)
          emit_project_analyzer_rule_summaries(summary)
          stdout.puts
        end

        def emit_block_metadata(cop_name, offense)
          emit_why_block(cop_name, offense[:why_it_matters])
          emit_project_analyzer_triage(offense[:project_analyzer])
        end

        def emit_offense_lines(list)
          list.each { |o| stdout.puts "  #{o[:path]}:#{o[:line]}:#{o[:column]} #{o[:message]}" }
        end

        def emit_project_analyzer_summary_heading(summary)
          stdout.puts "Project analyzers: #{count_label(summary.fetch('finding_count'), 'finding')}, " \
                      "#{count_label(summary.fetch('offense_count'), 'offense')} " \
                      "(opt-in advisory signals; review in context)"
        end

        def emit_project_analyzer_rule_summaries(summary)
          Array(summary["rules"]).each { |rule| stdout.puts "  #{project_analyzer_rule_summary(rule)}" }
        end

        def project_analyzer_rule_summary(rule)
          "#{rule.fetch('cop_name')}: #{count_label(rule.fetch('finding_count'), 'finding')}, " \
            "#{count_label(rule.fetch('offense_count'), 'offense')}, status: #{rule.fetch('status')}, " \
            "confidence: #{rule.fetch('confidence')}, severity: #{rule.fetch('triage_severity')}"
        end

        def emit_why_block(cop_name, why)
          return if why.nil? || why.empty?

          stdout.puts "  Why it matters: #{why}"
          stdout.puts "  Run `metz-scan explain #{cop_name}` for details." if explainable?(cop_name)
        end

        def emit_project_analyzer_triage(metadata)
          line = ProjectAnalyzerTriageFormatter.line(metadata)
          return unless line

          stdout.puts "  #{line}"
        end

        def count_label(count, noun)
          "#{count} #{noun}#{'s' unless count == 1}"
        end

        def explainable?(cop_name)
          cop_name.start_with?("Metz/")
        end

        def heading(name)
          tty? ? "#{ANSI_BOLD}#{ANSI_CYAN}#{name}#{ANSI_RESET}" : name
        end

        def tty?
          stdout.respond_to?(:tty?) && stdout.tty?
        end
      end
    end
  end
end
