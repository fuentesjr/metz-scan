# frozen_string_literal: true

require_relative "file_classifier"

module Metz
  # Shared iteration backbone for line-based Ruby extractors that target
  # indentation-driven template languages (HAML, Slim). Concrete extractors
  # define three patterns -- an expression line, a statement line, and a
  # filter-block start -- and this module walks the raw source line by
  # line, hands every matching body to RuboCop as its own ProcessedSource,
  # and tracks the byte offset of each body inside the original template
  # so offense locations refer back to the source file rather than the
  # synthetic snippet.
  module TemplateRubyExtractor
    def call(processed_source)
      path = processed_source.path
      return nil unless path && handles?(path)

      snippets = Walker.new(self, processed_source).snippets
      snippets << empty_snippet(processed_source) if snippets.empty?
      snippets
    end

    def install!
      extractors = RuboCop::Runner.ruby_extractors
      entrypoint = method(:call)
      extractors.unshift(entrypoint) unless extractors.include?(entrypoint)
    end

    def empty_snippet(processed_source)
      ps = build_processed_source("", processed_source)
      { offset: 0, processed_source: ps }
    end

    def build_snippet(body, body_offset, processed_source)
      return nil if body.strip.empty?

      ps = build_processed_source(body, processed_source)
      return nil unless ps.valid_syntax?

      { offset: body_offset, processed_source: ps }
    end

    def build_processed_source(body, processed_source)
      ruby_version = processed_source.ruby_version || RUBY_VERSION.to_f
      RuboCop::ProcessedSource.new(body, ruby_version, processed_source.path)
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
        @snippets << next_snippet until @cursor.done?
        @snippets.compact!
      end

      def next_snippet
        line = @cursor.line
        filter = line.match(@owner::FILTER_LINE)
        return consume_filter(filter) if filter

        consume_inline(line.match(@owner::EXPR_LINE) || line.match(@owner::STMT_LINE))
      end

      def consume_inline(match)
        snippet = inline_snippet(match)
        @cursor.advance(1)
        snippet
      end

      def inline_snippet(match)
        return nil if match.nil?

        body_offset = @cursor.offset + match.begin(:body)
        @owner.build_snippet(match[:body], body_offset, @processed_source)
      end

      def consume_filter(match)
        body_offset = @cursor.offset + @cursor.line.length
        body_lines = collect_filter_body(match[:indent].length)
        snippet = build_filter_snippet(body_lines, body_offset)
        @cursor.advance(1 + body_lines.size)
        snippet
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

      def build_filter_snippet(body_lines, body_offset)
        return nil if body_lines.empty?

        @owner.build_snippet(body_lines.join, body_offset, @processed_source)
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
