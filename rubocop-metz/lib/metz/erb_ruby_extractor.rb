# frozen_string_literal: true

require_relative "template_ruby_fragment"

module Metz
  # Ruby extractor for ERB templates. Registered with
  # `RuboCop::Runner.ruby_extractors` so that view-aware Metz cops (currently
  # `Metz/ViewsDeepNavigation`) can run against ERB content. RuboCop's parser
  # would otherwise emit `Lint/Syntax` for any `.erb` file because the raw
  # template is not a valid Ruby program. Every `.erb` file is extracted;
  # each cop's own scope decides which files it checks.
  #
  # The extractor scans for ERB tags, hands each `<% ... %>`, `<%= ... %>`, and
  # `<%== ... %>` body to RuboCop as its own `ProcessedSource`, and records the byte offset
  # of the body inside the original template. RuboCop adds that offset back
  # to every offense location, so reported line / column numbers point at
  # the original `.erb` file -- not the synthetic snippet.
  #
  # Control-flow openers such as `<% if ... %>` and block openers such as
  # `<%= form_with(...) do |f| %>` are reduced to their expression (see
  # `Metz::TemplateRubyFragment`). ERB comments (`<%# ... %>`) and escaped
  # tags (`<%%= ... %>`) are skipped.
  module ErbRubyExtractor
    ERB_TAG = /<%(?<kind>==|[-=#%]?)(?<body>.*?)-?%>/m
    # `<%#` is a comment and `<%%` an escaped literal `<%`; neither holds Ruby.
    SKIPPED_KINDS = %w[# %].freeze

    module_function

    def call(processed_source)
      path = processed_source.path
      return nil unless path && handles?(path)

      snippets = extract_snippets(processed_source)
      snippets << TemplateRubyFragment.empty(processed_source) if snippets.empty?
      snippets
    end

    def handles?(path)
      File.extname(path.to_s) == ".erb"
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
      return if SKIPPED_KINDS.include?(match[:kind])

      TemplateRubyFragment.snippet(match[:body], match.begin(:body), processed_source)
    end
  end
end
