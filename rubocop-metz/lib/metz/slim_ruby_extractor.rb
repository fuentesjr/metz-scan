# frozen_string_literal: true

require "strscan"
require_relative "template_ruby_extractor"

module Metz
  # Ruby extractor for Slim view templates. Mirrors `Metz::ErbRubyExtractor`:
  # registered with `RuboCop::Runner.ruby_extractors` so view-aware Metz cops
  # (currently `Metz/ViewsDeepNavigation`) can run against Slim content.
  #
  # Recognises the Slim constructs that carry Ruby:
  #
  #   * `= expr`, `== expr` - output script, bare or after a tag
  #                           (`p = expr`, `a.link[href=url] == expr`)
  #   * `- stmt`            - control code, including control openers
  #                           (`- if cond`, `- items.each do |item|`)
  #   * `title=expr`        - unquoted Ruby attribute values, bare
  #                           (`p title=expr`) or wrapped (`a[href=expr]`)
  #   * `ruby:` filter      - indented block of plain Ruby
  #
  # Quoted attribute values, text, comments, and other filters' bodies
  # (`javascript:`, `css:`, `markdown:`, ...) are not extracted, nor are
  # inline nested tags (`li: a href=expr`) or splat attributes (`*hash`).
  # Every `.slim` file is extracted; each cop's own scope decides which
  # files it checks.
  # Each fragment is handed to RuboCop as its own `ProcessedSource` whose
  # offset points at the fragment's column in the original template;
  # fragments that are not valid Ruby on their own are skipped.
  module SlimRubyExtractor
    extend TemplateRubyExtractor

    CONTROL_LINE = /\A[ \t]*-[ \t]*(?<body>.*)$/
    TAG          = /[ \t]*(?:[a-zA-Z][\w:-]*(?:[.#][\w-]+)*|(?:[.#][\w-]+)+)/
    OUTPUT       = /\G[ \t]*==?[<>']*[ \t]*(?<body>.*)$/
    FILTER_LINE  = /\A(?<indent>[ \t]*)(?<name>\w+):[ \t]*$/

    module_function

    def handles?(path)
      File.extname(path.to_s) == ".slim"
    end

    def line_fragments(line, processed_source)
      control = line.match(CONTROL_LINE)
      return [[control[:body], control.begin(:body)]] if control

      scanner = StringScanner.new(line.chomp)
      attributes = scanner.skip(TAG) ? Attributes.new(scanner, processed_source).fragments : []
      [*attributes, output(scanner)].compact
    end

    def output(scanner)
      match = scanner.string.match(OUTPUT, scanner.pos)
      [match[:body], match.begin(:body)] if match
    end

    # Scans the attributes after a Slim tag, leaving the scanner just past
    # them. Like Slim itself, an unquoted value runs to the first space or
    # closing bracket outside nested brackets; the shortest such prefix that
    # parses as Ruby is taken as the value.
    class Attributes
      WRAPPERS = { "[" => "]", "(" => ")", "{" => "}" }.freeze
      UNWRAPPED_NAME = /[ \t]+[\w:@-]+==?/
      WRAPPED_NAME = /[ \t]*[\w:@-]+[ \t]*==?[ \t]*/
      BOOLEANS = /(?:[ \t]*[\w:@-]+(?=[ \t\])}]))*/
      QUOTED = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/

      def initialize(scanner, processed_source)
        @scanner = scanner
        @processed_source = processed_source
        @close = WRAPPERS[scanner.peek(1)]
        scanner.getch if @close
      end

      def fragments
        found = []
        found << value while attribute_name?
        @scanner.skip(/[ \t]*#{Regexp.escape(@close)}/) if @close
        found.compact
      end

      private

      def attribute_name?
        @scanner.skip(BOOLEANS) if @close
        @scanner.skip(@close ? WRAPPED_NAME : UNWRAPPED_NAME)
      end

      def value
        return if @scanner.skip(QUOTED)

        start = @scanner.pos
        stop = value_end(start)
        @scanner.pos = stop || @scanner.string.length
        [@scanner.string[start...stop], start] if stop
      end

      def value_end(start)
        string = @scanner.string
        ((start + 1)..string.length).find do |stop|
          delimiter?(string[stop]) && TemplateRubyFragment.valid?(string[start...stop], @processed_source)
        end
      end

      def delimiter?(char)
        char.nil? || char.match?(@close ? /[ \t\])}]/ : /[ \t]/)
      end
    end
  end
end
