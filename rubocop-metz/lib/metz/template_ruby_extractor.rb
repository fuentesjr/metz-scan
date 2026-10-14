# frozen_string_literal: true

require_relative "template_ruby_fragment"

module Metz
  # Shared iteration backbone for line-based Ruby extractors that target
  # indentation-driven template languages (HAML, Slim). Concrete extractors
  # define a filter-block start pattern (`FILTER_LINE`, capturing the filter
  # `name`) and `line_fragments(line, processed_source)`, which returns the
  # `[ruby_source, column]` pairs a single template line carries. Every
  # filter's indented body is consumed, but only a `ruby` filter's body is
  # Ruby; other filters (`javascript`, `css`, `markdown`, ...) yield nothing. This
  # module walks the raw source line by line, hands every fragment to
  # RuboCop as its own ProcessedSource, and tracks the offset of each
  # fragment inside the original template so offense locations refer back
  # to the source file rather than the synthetic snippet.
  module TemplateRubyExtractor
    def call(processed_source)
      path = processed_source.path
      return nil unless path && handles?(path)

      snippets = Walker.new(self, processed_source).snippets
      snippets << TemplateRubyFragment.empty(processed_source) if snippets.empty?
      snippets
    end

    def install!
      extractors = RuboCop::Runner.ruby_extractors
      entrypoint = method(:call)
      extractors.unshift(entrypoint) unless extractors.include?(entrypoint)
    end

    # Walks lines of a template, dispatching each line to the owner module's
    # match patterns. Holds the running byte offset, the line index, and the
    # accumulating snippet list so the owner module can stay stateless.
    class Walker
      def initialize(owner, processed_source)
        @owner = owner
        @processed_source = processed_source
        @cursor = Cursor.new(processed_source.raw_source.lines)
        walk
      end

      attr_reader :snippets

      def walk
        @snippets = []
        @snippets.concat(next_snippets) until @cursor.done?
        @snippets.compact!
      end

      def next_snippets
        line = @cursor.line
        filter = line.match(@owner::FILTER_LINE)
        return [consume_filter(filter)] if filter

        consume_inline(line)
      end

      def consume_inline(line)
        snippets = @owner.line_fragments(line, @processed_source).map { |body, column| inline_snippet(body, column) }
        @cursor.advance(1)
        snippets
      end

      def inline_snippet(body, column)
        TemplateRubyFragment.snippet(body, @cursor.offset + column, @processed_source)
      end

      def consume_filter(match)
        body_offset = @cursor.offset + @cursor.line.length
        body = collect_filter_body(match[:indent].length)
        @cursor.advance(1 + body.size)
        TemplateRubyFragment.snippet(body.join, body_offset, @processed_source) if match[:name] == "ruby"
      end

      def collect_filter_body(base_indent)
        body = []
        body << @cursor.peek(body.size + 1) while filter_member?(body.size + 1, base_indent)
        body
      end

      def filter_member?(lookahead, base_indent)
        line = @cursor.peek(lookahead)
        return false if line.nil?

        line.match?(/\A\s*\z/) || leading_indent(line) > base_indent
      end

      def leading_indent(line)
        line[/\A[ \t]*/].length
      end
    end

    # Tracks the running byte offset and line index while walking a template.
    class Cursor
      def initialize(lines)
        @lines = lines
        @index = 0
        @offset = 0
      end

      attr_reader :offset

      def done?
        @index >= @lines.size
      end

      def line
        @lines[@index]
      end

      def peek(lookahead)
        @lines[@index + lookahead]
      end

      def advance(count)
        count.times do
          break if done?

          @offset += @lines[@index].length
          @index += 1
        end
      end
    end
  end
end
