# frozen_string_literal: true

require "optparse"

require_relative "version"

module MetzScan
  class CLI
    SUBCOMMAND_SUMMARIES = {
      "rules" => "List all Metz/* cops with their one-line rationale",
      "explain" => "Print full metadata for a single Metz cop",
      "scan" => "Run rubocop-metz against PATH and render a report",
      "report" => "Re-render an existing rubocop-metz JSON report"
    }.freeze

    SUBCOMMANDS = SUBCOMMAND_SUMMARIES.keys.freeze

    def self.start(argv = ARGV, stdout: $stdout, stderr: $stderr)
      new(stdout: stdout, stderr: stderr).run(argv)
    end

    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      args = argv.dup
      return show_help_and_fail if args.empty?

      handle_global_flag(args.first) || dispatch(args)
    end

    private

    attr_reader :stdout, :stderr

    def handle_global_flag(arg)
      case arg
      when "-v", "--version" then print_version
      when "-h", "--help"    then print_help_and_succeed
      end
    end

    def print_version
      stdout.puts MetzScan::VERSION
      0
    end

    def print_help_and_succeed
      stdout.puts help_text
      0
    end

    def show_help_and_fail
      stderr.puts help_text
      1
    end

    def dispatch(args)
      name = args.shift
      return unknown_subcommand(name) unless SUBCOMMANDS.include?(name)

      handler = subcommand_handler(name)
      handler ? handler.run(args, stdout: stdout, stderr: stderr) : stub_subcommand(name)
    end

    SUBCOMMAND_HANDLERS = { "rules" => "Rules", "explain" => "Explain", "scan" => "Scan",
                            "report" => "Report" }.freeze
    private_constant :SUBCOMMAND_HANDLERS

    def subcommand_handler(name)
      klass_name = SUBCOMMAND_HANDLERS[name]
      return unless klass_name

      require_relative "commands/#{name}"
      Commands.const_get(klass_name)
    end

    def stub_subcommand(name)
      stderr.puts "metz-scan: subcommand '#{name}' is not yet implemented."
      1
    end

    def unknown_subcommand(name)
      stderr.puts "metz-scan: unknown subcommand '#{name}'."
      stderr.puts help_text
      1
    end

    def help_text
      option_parser.help
    end

    def option_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: metz-scan [--version] [--help] <subcommand> [<args>]"
        append_subcommands(opts)
        append_options(opts)
      end
    end

    SUBCOMMAND_ROW = "    %<name>-9s %<summary>s"
    private_constant :SUBCOMMAND_ROW

    def append_subcommands(opts)
      opts.separator ""
      opts.separator "Subcommands:"
      SUBCOMMAND_SUMMARIES.each { |name, summary| opts.separator(format(SUBCOMMAND_ROW, name: name, summary: summary)) }
    end

    def append_options(opts)
      opts.separator ""
      opts.separator "Options:"
      opts.on("-v", "--version", "Print the metz-scan version and exit")
      opts.on("-h", "--help",    "Show this help message and exit")
    end
  end
end
