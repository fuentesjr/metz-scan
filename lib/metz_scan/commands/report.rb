# frozen_string_literal: true

require "json"
require "optparse"

require_relative "scan/runner"
require_relative "scan/compliance_scorecard"
require_relative "scan/text_renderer"
require_relative "scan/sarif_renderer"
require_relative "scan/github_annotations_renderer"

module MetzScan
  module Commands
    class Report
      USAGE = "Usage: metz-scan report PATH/TO/JSON [--format text|json|sarif|gh-annotations]"
      VALID_FORMATS = %w[text json sarif gh-annotations].freeze
      RENDERERS = { "sarif" => Scan::SarifRenderer, "gh-annotations" => Scan::GithubAnnotationsRenderer }.freeze
      DEFAULT_FORMAT = "text"

      Options = Struct.new(:format, :path, keyword_init: true)

      def self.run(argv, stdout:, stderr:)
        new(stdout: stdout, stderr: stderr).run(argv)
      end

      def initialize(stdout:, stderr:)
        @stdout = stdout
        @stderr = stderr
      end

      def run(argv)
        options = parse_options(argv)
        validate(options) || emit(options)
      rescue OptionParser::ParseError => e
        parser_error(e)
      end

      private

      attr_reader :stdout, :stderr

      def parse_options(argv)
        flags = { format: DEFAULT_FORMAT }
        rest = OptionParser.new { |opts| configure_parser(opts, flags) }.parse(argv)
        Options.new(**flags, path: rest.first)
      end

      def configure_parser(opts, flags)
        opts.banner = USAGE
        opts.on("--format FORMAT", "Output format: text (default), json, sarif, gh-annotations") do |format|
          flags[:format] = format
        end
      end

      def validate(options)
        return missing_path_arg unless options.path
        return missing_file(options.path) unless File.file?(options.path)

        invalid_format(options.format) unless VALID_FORMATS.include?(options.format)
      end

      def emit(options)
        parsed = load_json(options.path)
        return parsed if parsed.is_a?(Integer)

        render(parsed, options.format)
        Scan::Runner.exit_code_for(parsed)
      end

      def load_json(path)
        JSON.parse(File.read(path))
      rescue JSON::ParserError => e
        invalid_json(path, e.message)
      end

      def render(parsed, format)
        return render_json(parsed) if format == "json"

        RENDERERS.fetch(format, Scan::TextRenderer).new(stdout, parsed).render
      end

      def render_json(parsed)
        Scan::ComplianceScorecard.add_to_summary!(parsed)
        stdout.puts JSON.generate(parsed)
      end

      def parser_error(err)
        stderr.puts "metz-scan report: #{err.message}"
        stderr.puts USAGE
        1
      end

      def missing_path_arg
        stderr.puts "metz-scan report: missing PATH argument."
        stderr.puts USAGE
        1
      end

      def missing_file(path)
        stderr.puts "metz-scan report: no such file: #{path}"
        1
      end

      def invalid_format(fmt)
        stderr.puts "metz-scan report: invalid --format '#{fmt}'. Valid formats: text, json, sarif, gh-annotations."
        1
      end

      def invalid_json(path, detail)
        stderr.puts "metz-scan report: invalid JSON in #{path}: #{detail}"
        1
      end
    end
  end
end
