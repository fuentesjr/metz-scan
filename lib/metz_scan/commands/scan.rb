# frozen_string_literal: true

require "json"
require "optparse"
require "stringio"

require_relative "../version"
require_relative "scan/check_failure"
require_relative "scan/compliance_scorecard"
require_relative "scan/runner"
require_relative "scan/project_analyzer_runner"
require_relative "scan/text_renderer"
require_relative "scan/sarif_renderer"
require_relative "scan/github_annotations_renderer"
require_relative "scan/baseline_filter"
require_relative "scan/baseline_loader"
require_relative "scan/ignored_cli_options_note"
require_relative "scan/json_guidance"
require_relative "../cli"

module MetzScan
  module Commands
    class ScanOptions
      USAGE = "Usage: metz-scan scan PATH... [--baseline FILE] [--format text|json|sarif|gh-annotations] " \
              "[--all-cops] [--project-analyzers]"
      VALID_FORMATS = %w[text json sarif gh-annotations].freeze
      DEFAULT_FORMAT = "text"

      Options = Struct.new(:format, :paths, :baseline, :all_cops, :project_analyzers, :help, keyword_init: true)

      def self.parse(argv) = new.parse(argv)

      def self.help = new.help

      def parse(argv)
        flags = default_flags
        paths = option_parser(flags).parse(argv)
        Options.new(**flags, paths: paths)
      end

      def help = option_parser(default_flags).help

      private

      def default_flags
        { format: DEFAULT_FORMAT, baseline: nil, all_cops: false, project_analyzers: false, help: false }
      end

      def option_parser(flags) = OptionParser.new(USAGE) { |opts| configure_parser(opts, flags) }

      def configure_parser(opts, flags)
        configure_baseline_parser(opts, flags)
        configure_format_parser(opts, flags)
        configure_cop_selection_parser(opts, flags)
        configure_project_analyzer_parser(opts, flags)
        configure_help_parser(opts, flags)
      end

      def configure_baseline_parser(opts, flags)
        opts.on("--baseline FILE", "Report only new or grown findings compared to a saved JSON scan report") do |file|
          flags[:baseline] = file
        end
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

      def configure_help_parser(opts, flags)
        opts.on("-h", "--help", "Show this help message and exit") { flags[:help] = true }
      end
    end

    class Scan
      USAGE = ScanOptions::USAGE
      VALID_FORMATS = ScanOptions::VALID_FORMATS

      def self.run(argv, stdout:, stderr:) = new(stdout: stdout, stderr: stderr).run(argv)

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
        @baseline = nil
      end

      def run(argv)
        handle_options(parse_options(argv))
      rescue OptionParser::ParseError => e
        parser_error(e)
      rescue *CheckFailure::INTERNAL_ERRORS => e
        CheckFailure.new(stderr).report(e)
      end

      private

      attr_reader :stdout, :stderr

      def handle_options(options)
        return print_help if options.help

        validate(options) || scan(options)
      end

      def parse_options(argv) = ScanOptions.parse(argv)

      def validate(options)
        return missing_path_arg if options.paths.empty?
        return missing_paths(options.paths) unless options.paths.all? { |p| File.exist?(p) }
        return invalid_format(options.format) unless VALID_FORMATS.include?(options.format)

        validate_baseline(options.baseline) if options.baseline
      end

      # The report reaches stdout only after every step succeeded; see CheckFailure.
      def scan(options)
        run_scan(options, options.all_cops ? {} : TargetFileDiscovery.scan_scope(options.paths))
      end

      def run_scan(options, scope)
        parsed = build_report(options, scope)
        stdout.write(rendered(parsed, options))
        IgnoredCliOptionsNote.print_note(stderr)
        Runner.exit_code_for(parsed)
      end

      def build_report(options, scope)
        parsed = checked_report(options, scope)
        entries = merge_project_analyzers(parsed, options, scope)
        ComplianceScorecard.record_file_counts!(parsed)
        BaselineFilter.apply!(parsed, @baseline, analyzer_entries: entries) if @baseline
        ComplianceScorecard.add_to_summary!(parsed)
      end

      def checked_report(options, scope)
        parsed = Runner.invoke(options.paths, all_cops: options.all_cops, stderr: stderr, **scope)
        raise CheckFailure::NoFilesScanned, options.paths if parsed.dig("summary", "inspected_file_count").zero?

        parsed
      end

      def merge_project_analyzers(parsed, options, scope)
        entries = []
        opts = { default_output: !options.project_analyzers, all_cops: options.all_cops,
                 analyzer_entries: entries, **scope }
        ProjectAnalyzerRunner.merge!(parsed, options.paths, **opts)
        entries
      end

      def rendered(parsed, options) = StringIO.new.tap { |out| render(out, parsed, options) }.string

      # Text and SARIF render the compacted report so live output matches `report` on the saved JSON.
      def render(out, parsed, options)
        format = options.format
        return GithubAnnotationsRenderer.new(out, parsed).render if format == "gh-annotations"

        JsonGuidance.compact!(parsed, all_cops: options.all_cops)
        return out.puts JSON.generate(parsed) if format == "json"

        (format == "sarif" ? SarifRenderer : TextRenderer).new(out, parsed).render
      end

      def parser_error(err)
        stderr.puts "metz-scan scan: #{err.message}"
        stderr.puts USAGE
        CLI::USAGE_ERROR
      end

      def print_help
        stdout.puts ScanOptions.help
        0
      end

      def missing_path_arg
        stderr.puts "metz-scan scan: missing PATH argument."
        stderr.puts USAGE
        CLI::USAGE_ERROR
      end

      def missing_paths(paths)
        paths.reject { |p| File.exist?(p) }.each { |p| stderr.puts "metz-scan scan: no such file or directory: #{p}" }
        CLI::USAGE_ERROR
      end

      def invalid_format(fmt)
        stderr.puts "metz-scan scan: invalid --format '#{fmt}'. Valid formats: text, json, sarif, gh-annotations."
        CLI::USAGE_ERROR
      end

      def validate_baseline(path)
        @baseline = BaselineLoader.load(path)
        nil
      rescue BaselineLoader::Error => e
        invalid_baseline(path, e.message)
      end

      def invalid_baseline(path, reason)
        stderr.puts "metz-scan scan: invalid --baseline '#{path}': #{reason}"
        CLI::USAGE_ERROR
      end
    end
  end
end
