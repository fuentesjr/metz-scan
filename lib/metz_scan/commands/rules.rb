# frozen_string_literal: true

require "json"
require "optparse"

module MetzScan
  module Commands
    class Rules
      ANSI_RESET = "\e[0m"
      ANSI_BOLD = "\e[1m"
      ANSI_CYAN = "\e[36m"
      ANSI_GREY = "\e[90m"

      USAGE = "Usage: metz-scan rules [--json]"

      def self.run(argv, stdout:, stderr:)
        new(stdout: stdout, stderr: stderr).run(argv)
      end

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
      end

      def run(argv)
        options = parse_options(argv)
        cops = load_cops
        options[:json] ? emit_json(cops) : emit_table(cops)
        0
      end

      private

      attr_reader :stdout, :stderr

      def parse_options(argv)
        options = { json: false }
        OptionParser.new { |opts| configure_options(opts, options) }.parse!(argv)
        options
      end

      def configure_options(opts, options)
        opts.banner = USAGE
        opts.on("--json", "Emit a JSON array of all Metz cops") { options[:json] = true }
      end

      def load_cops
        require "rubocop-metz"
        RuboCop::Cop::Registry.global.cops.select { |cop| cop.cop_name.start_with?("Metz/") }.sort_by(&:cop_name)
      end

      def emit_json(cops)
        stdout.puts JSON.generate(cops.map { |cop| json_entry(cop) })
      end

      def json_entry(cop)
        { name: cop.cop_name, why_it_matters: cop.why_it_matters,
          fix_safety: cop.fix_safety.to_s, suggested_next_moves: Array(cop.suggested_next_moves) }
      end

      def emit_table(cops)
        name_width = cops.map { |cop| cop.cop_name.length }.max
        colorize = tty?
        stdout.puts header_row(name_width, colorize)
        stdout.puts separator_row(name_width, colorize)
        cops.each { |cop| stdout.puts data_row(cop, name_width, colorize) }
      end

      def tty?
        stdout.respond_to?(:tty?) && stdout.tty?
      end

      def header_row(name_width, colorize)
        decorate(format("%-#{name_width}s  %s", "COP", "WHY IT MATTERS"), ANSI_BOLD, colorize)
      end

      def separator_row(name_width, colorize)
        dashes = ("-" * name_width)
        decorate("#{dashes}  #{'-' * 14}", ANSI_GREY, colorize)
      end

      def data_row(cop, name_width, colorize)
        colored_name = decorate(format("%-#{name_width}s", cop.cop_name), ANSI_CYAN, colorize)
        "#{colored_name}  #{cop.why_it_matters}"
      end

      def decorate(text, code, colorize)
        colorize ? "#{code}#{text}#{ANSI_RESET}" : text
      end
    end
  end
end
