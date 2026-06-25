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
        STATUS_PRIORITY = { "candidate" => 0, "experimental" => 1 }.freeze
        CONFIDENCE_PRIORITY = { "high" => 0, "medium" => 1, "early" => 2 }.freeze
        TRIAGE_SEVERITY_PRIORITY = { "design pressure" => 0, "manual review" => 1 }.freeze

        def initialize(stdout, parsed)
          @stdout = stdout
          @parsed = parsed
        end

        def render
          emit_project_analyzer_summary
          sorted_offense_blocks.each do |cop_name, list|
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
          sorted_project_analyzer_rules(summary).each { |rule| stdout.puts "  #{project_analyzer_rule_summary(rule)}" }
        end

        def project_analyzer_rule_summary(rule)
          "#{rule.fetch('cop_name')}: #{count_label(rule.fetch('finding_count'), 'finding')}, " \
            "#{count_label(rule.fetch('offense_count'), 'offense')}, status: #{rule.fetch('status')}, " \
            "confidence: #{rule.fetch('confidence')}, severity: #{rule.fetch('triage_severity')}"
        end

        def sorted_offense_blocks
          OffenseExtractor.offenses(parsed)
                          .group_by { |offense| offense[:cop_name] }
                          .sort_by { |cop_name, list| offense_block_sort_key(cop_name, list.first) }
        end

        def offense_block_sort_key(cop_name, offense)
          metadata = offense[:project_analyzer]
          return [0, cop_name] unless metadata

          [1, *project_analyzer_priority(metadata), cop_name]
        end

        def sorted_project_analyzer_rules(summary)
          Array(summary["rules"]).sort_by do |rule|
            [*project_analyzer_priority(rule), rule.fetch("cop_name")]
          end
        end

        def project_analyzer_priority(metadata)
          [
            priority_for(STATUS_PRIORITY, metadata["status"]),
            priority_for(CONFIDENCE_PRIORITY, metadata["confidence"]),
            priority_for(TRIAGE_SEVERITY_PRIORITY, metadata["triage_severity"])
          ]
        end

        def priority_for(priority_table, value)
          priority_table.fetch(value, priority_table.size)
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
