# frozen_string_literal: true

require "optparse"
require "yaml"

module MetzScan
  module Commands
    class Explain
      USAGE = "Usage: metz-scan explain Metz/CopName"
      NON_KNOB_KEYS = %w[Description VersionAdded StyleGuide Reference].freeze

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
      end

      def emit_or_error(cop_name)
        cop = lookup_metz_cop(cop_name)
        return unknown_cop_error(cop_name) unless cop

        emit(cop)
        0
      end

      private

      attr_reader :stdout, :stderr

      def parse_options(argv)
        OptionParser.new { |opts| opts.banner = USAGE }.parse!(argv)
        argv
      end

      def lookup_metz_cop(name)
        require "rubocop-metz"
        cop = RuboCop::Cop::Registry.global.find_by_cop_name(name)
        cop if cop && metz_cop?(cop)
      end

      def metz_cop?(cop)
        base = RuboCop::Cop::Metz::Base
        cop != base && cop < base
      end

      def missing_argument_error
        stderr.puts "metz-scan explain: missing required COP_NAME argument."
        stderr.puts USAGE
        stderr.puts "Run `metz-scan rules` to see the list of available Metz cops."
        1
      end

      def unknown_cop_error(name)
        stderr.puts "metz-scan explain: no such cop '#{name}'."
        stderr.puts "Run `metz-scan rules` to see the list of available Metz cops."
        1
      end

      def emit(cop)
        emit_heading(cop)
        emit_why(cop)
        emit_fix_safety(cop)
        emit_suggested_next_moves(cop)
        emit_configuration(cop)
      end

      def emit_heading(cop)
        stdout.puts cop.cop_name
        stdout.puts("=" * cop.cop_name.length)
        stdout.puts
      end

      def emit_why(cop)
        stdout.puts "Why it matters:"
        stdout.puts "  #{cop.why_it_matters}"
        stdout.puts
      end

      def emit_fix_safety(cop)
        stdout.puts "Fix safety: #{cop.fix_safety}"
        stdout.puts
      end

      def emit_suggested_next_moves(cop)
        stdout.puts "Suggested next moves:"
        cop.suggested_next_moves.each { |move| stdout.puts "  - #{move}" }
        stdout.puts
      end

      def emit_configuration(cop)
        knobs = configuration_knobs(cop.cop_name)
        return if knobs.empty?

        stdout.puts "Configuration:"
        knobs.each { |key, value| stdout.puts "  #{key}: #{format_value(value)}" }
      end

      def configuration_knobs(cop_name)
        entry = default_config[cop_name] || {}
        entry.except(*NON_KNOB_KEYS)
      end

      def default_config
        @default_config ||= YAML.load_file(default_config_path)
      end

      def default_config_path
        RuboCop::Metz::Plugin.new.rules(nil).value.to_s
      end

      def format_value(value)
        case value
        when Array then value.empty? ? "[]" : value.join(", ")
        else value.to_s
        end
      end
    end
  end
end
