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
  # Tags whose body is not valid Ruby on its own (the open half of a
  # `<% if ... %> ... <% end %>` pair, for example) are silently skipped:
  # we do not want them to fire `Lint/Syntax`. ERB comments (`<%# ... %>`)
  # are skipped as well.
  module ErbRubyExtractor
    ERB_TAG = /<%(?<kind>[-=#]?)(?<body>.*?)-?%>/m

    module_function

    def call(processed_source)
      path = processed_source.path
      return nil unless path && ::Metz::FileClassifier.view?(path)

      snippets = extract_snippets(processed_source)
      snippets << empty_snippet(processed_source) if snippets.empty?
      snippets
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
      ps = RuboCop::ProcessedSource.new(match[:body], ruby_version, processed_source.path)
      return unless ps.valid_syntax?

      { offset: match.begin(:body), processed_source: ps }
    end

    def empty_snippet(processed_source)
      ruby_version = processed_source.ruby_version || RUBY_VERSION.to_f
      ps = RuboCop::ProcessedSource.new("", ruby_version, processed_source.path)
      { offset: 0, processed_source: ps }
    end
  end
end
