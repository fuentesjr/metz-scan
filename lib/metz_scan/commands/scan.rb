# frozen_string_literal: true

require "json"
require "optparse"

require_relative "../version"
require_relative "scan/runner"
require_relative "scan/project_analyzer_runner"
require_relative "scan/text_renderer"
require_relative "scan/sarif_renderer"
require_relative "scan/github_annotations_renderer"
require_relative "scan/auto_fix"

module MetzScan
  module Commands
    class ScanOptions
      USAGE = "Usage: metz-scan scan PATH... [--format text|json|sarif|gh-annotations] " \
              "[--all-cops] [--project-analyzers] [--auto-fix [--unsafe] [--dry-run]]"
      VALID_FORMATS = %w[text json sarif gh-annotations].freeze
      DEFAULT_FORMAT = "text"

      Options = Struct.new(:format, :paths, :all_cops, :project_analyzers, :auto_fix, :unsafe, :dry_run, :help,
                           keyword_init: true)

      def self.parse(argv)
        new.parse(argv)
      end

      def self.help
        new.help
      end

      def parse(argv)
        flags = default_flags
        paths = option_parser(flags).parse(argv)
        Options.new(**flags, paths: paths)
      end

      def help
        option_parser(default_flags).help
      end

      private

      def default_flags
        { format: DEFAULT_FORMAT, all_cops: false, project_analyzers: false, auto_fix: false, unsafe: false,
          dry_run: false, help: false }
      end

      def option_parser(flags)
        OptionParser.new(USAGE) { |opts| configure_parser(opts, flags) }
      end

      def configure_parser(opts, flags)
        configure_format_parser(opts, flags)
        configure_cop_selection_parser(opts, flags)
        configure_project_analyzer_parser(opts, flags)
        configure_auto_fix_parser(opts, flags)
        configure_help_parser(opts, flags)
      end

      def configure_format_parser(opts, flags)
        opts.on("--format FORMAT", "Output format: text (default), json, sarif, gh-annotations") do |format|
          flags[:format] = format
        end
      end

      def configure_cop_selection_parser(opts, flags)
        opts.on("--all-cops", "Run the full RuboCop suite instead of Metz/* cops by default") do
          flags[:all_cops] = true
        end
      end

      def configure_project_analyzer_parser(opts, flags)
        opts.on("--project-analyzers", "Include all opt-in project analyzer findings") do
          flags[:project_analyzers] = true
        end
      end

      def configure_auto_fix_parser(opts, flags)
        opts.on("--auto-fix", "Apply RuboCop's safe fixes (delegates to rubocop -a)") { flags[:auto_fix] = true }
        opts.on("--unsafe", "With --auto-fix, also apply unsafe fixes (rubocop -A)") { flags[:unsafe] = true }
        opts.on("--dry-run", "With --auto-fix, print diff without modifying files") { flags[:dry_run] = true }
      end

      def configure_help_parser(opts, flags)
        opts.on("-h", "--help", "Show this help message and exit") { flags[:help] = true }
      end
    end

    class Scan
      USAGE = ScanOptions::USAGE
      VALID_FORMATS = ScanOptions::VALID_FORMATS
      RENDERERS = { "sarif" => SarifRenderer, "gh-annotations" => GithubAnnotationsRenderer }.freeze

      def self.run(argv, stdout:, stderr:)
        new(stdout: stdout, stderr: stderr).run(argv)
      end

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
      end

      def run(argv)
        handle_options(parse_options(argv))
      rescue OptionParser::ParseError => e
        parser_error(e)
      rescue Runner::Error => e
        runner_error(e)
      end

      private

      attr_reader :stdout, :stderr

      def handle_options(options)
        return print_help if options.help

        validate(options) || dispatch(options)
      end

      def parse_options(argv)
        ScanOptions.parse(argv)
      end

      def validate(options)
        return missing_path_arg if options.paths.empty?
        return missing_paths(options.paths) unless options.paths.all? { |p| File.exist?(p) }
        return nil if options.auto_fix

        invalid_format(options.format) unless VALID_FORMATS.include?(options.format)
      end

      def dispatch(options)
        return AutoFix.new(stdout: stdout, stderr: stderr).run(options) if options.auto_fix

        scan(options)
      end

      def scan(options)
        parsed = Runner.invoke(options.paths, all_cops: options.all_cops)
        merge_project_analyzers(parsed, options)
        render(parsed, options.format)
        Runner.exit_code_for(parsed)
      end

      def merge_project_analyzers(parsed, options)
        ProjectAnalyzerRunner.merge!(parsed, options.paths, **project_analyzer_options(options))
      end

      def project_analyzer_options(options)
        { default_output: !options.project_analyzers, force_default_config: !options.all_cops }
      end

      def render(parsed, format)
        return stdout.puts JSON.generate(parsed) if format == "json"

        RENDERERS.fetch(format, TextRenderer).new(stdout, parsed).render
      end

      def parser_error(err)
        stderr.puts "metz-scan scan: #{err.message}"
        stderr.puts USAGE
        1
      end

      def print_help
        stdout.puts ScanOptions.help
        0
      end

      def missing_path_arg
        stderr.puts "metz-scan scan: missing PATH argument."
        stderr.puts USAGE
        1
      end

      def missing_paths(paths)
        paths.reject { |p| File.exist?(p) }.each { |p| stderr.puts "metz-scan scan: no such file or directory: #{p}" }
        1
      end

      def invalid_format(fmt)
        stderr.puts "metz-scan scan: invalid --format '#{fmt}'. Valid formats: text, json, sarif, gh-annotations."
        1
      end

      def runner_error(err)
        stderr.puts "metz-scan scan: RuboCop failed: #{err.message}"
        2
      end
    end
  end
end
