# frozen_string_literal: true

require_relative "offense_extractor"

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
          OffenseExtractor.offenses(@parsed).group_by { |o| o[:cop_name] }.sort.each do |cop_name, list|
            render_block(cop_name, list)
          end
        end

        private

        attr_reader :stdout

        def render_block(cop_name, list)
          stdout.puts heading(cop_name)
          emit_why_block(cop_name, list.first[:why_it_matters])
          list.each { |o| stdout.puts "  #{o[:path]}:#{o[:line]}:#{o[:column]} #{o[:message]}" }
          stdout.puts
        end

        def emit_why_block(cop_name, why)
          return if why.nil? || why.empty?

          stdout.puts "  Why it matters: #{why}"
          stdout.puts "  Run `metz-scan explain #{cop_name}` for details." if explainable?(cop_name)
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
