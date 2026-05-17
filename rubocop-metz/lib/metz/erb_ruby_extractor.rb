# frozen_string_literal: true

require_relative "file_classifier"

module Metz
  # Ruby extractor for ERB / HAML / SLIM view templates. Registered with
  # `RuboCop::Runner.ruby_extractors` so that view-aware Metz cops (currently
  # `Metz/ViewsDeepNavigation`) can run against ERB content. RuboCop's parser
  # would otherwise emit `Lint/Syntax` for any `.erb` file because the raw
  # template is not a valid Ruby program.
  #
  # The extractor scans for ERB tags, hands each `<% ... %>` / `<%= ... %>`
  # body to RuboCop as its own `ProcessedSource`, and records the byte offset
  # of the body inside the original template. RuboCop adds that offset back
  # to every offense location, so reported line / column numbers point at
  # the original `.erb` file -- not the synthetic snippet.
  #
  # Control-flow openers such as `<% if ... %>` are reduced to the condition
  # expression. Other invalid fragments are skipped to avoid `Lint/Syntax`
  # noise. ERB comments (`<%# ... %>`) are skipped as well.
  module ErbRubyExtractor
    ERB_TAG = /<%(?<kind>[-=#]?)(?<body>.*?)-?%>/m
    CONTROL_CONDITION = /\A(?<prefix>\s*(?:if|unless|while|until|elsif|case)\b\s*)(?<expr>.*?)(?:\s+then)?\s*\z/m
    TRAILING_DO_BLOCK = /\A(?<expr>.*?)(?<suffix>\s+do\b(?:\s*\|[^|]*\|)?\s*)\z/m
    MAGIC_COMMENT = "# frozen_string_literal: true\n\n"

    module_function

    def call(processed_source)
      path = processed_source.path
      return nil unless path && handles?(path)

      snippets = extract_snippets(processed_source)
      snippets << empty_snippet(processed_source) if snippets.empty?
      snippets
    end

    def handles?(path)
      File.extname(path.to_s) == ".erb" && ::Metz::FileClassifier.view?(path)
    end

    def install!
      extractors = RuboCop::Runner.ruby_extractors
      extractor = method(:call)
      extractors.unshift(extractor) unless extractors.include?(extractor)
    end

    def extract_snippets(processed_source)
      enumerate_matches(processed_source.raw_source).filter_map do |match|
        snippet_for(match, processed_source)
      end
    end

    def enumerate_matches(raw, pos: 0, matches: [])
      while (match = raw.match(ERB_TAG, pos))
        matches << match
        pos = match.end(0)
      end
      matches
    end

    def snippet_for(match, processed_source)
      return if match[:kind] == "#"

      ruby_version = processed_source.ruby_version || RUBY_VERSION.to_f
      ps, offset = source_and_offset(match, ruby_version, processed_source.path)
      return unless ps

      { offset: offset, processed_source: ps }
    end

    def source_and_offset(match, ruby_version, path)
      body = match[:body]
      ps = RuboCop::ProcessedSource.new(body, ruby_version, path)
      return [ps, match.begin(:body)] if ps.valid_syntax?
      return unless code_tag?(match[:kind])

      expression_source(body, ruby_version, path, match.begin(:body))
    end

    def code_tag?(kind)
      kind.empty? || kind == "-"
    end

    def expression_source(body, ruby_version, path, body_offset)
      match = body.match(CONTROL_CONDITION) || body.match(TRAILING_DO_BLOCK)
      return unless match

      ps = RuboCop::ProcessedSource.new(control_expression(match[:expr]), ruby_version, path)
      [ps, expression_offset(body_offset, match)] if ps.valid_syntax?
    end

    def control_expression(expr)
      "#{MAGIC_COMMENT}#{expr}\n"
    end

    def expression_offset(body_offset, match)
      body_offset + match.begin(:expr) - MAGIC_COMMENT.bytesize
    end

    def empty_snippet(processed_source)
      ruby_version = processed_source.ruby_version || RUBY_VERSION.to_f
      ps = RuboCop::ProcessedSource.new("", ruby_version, processed_source.path)
      { offset: 0, processed_source: ps }
    end
  end
end
