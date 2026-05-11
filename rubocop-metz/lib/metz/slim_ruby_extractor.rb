# frozen_string_literal: true

require_relative "template_ruby_extractor"

module Metz
  # Ruby extractor for Slim view templates. Mirrors `Metz::ErbRubyExtractor`:
  # registered with `RuboCop::Runner.ruby_extractors` so view-aware Metz cops
  # (currently `Metz/ViewsDeepNavigation`) can run against Slim content.
  #
  # Recognises four Slim constructs that carry Ruby:
  #
  #   * `= ruby_expr`   - output script (escaped)
  #   * `== ruby_expr`  - output script (raw / unescaped)
  #   * `- ruby_stmt`   - silent script
  #   * `ruby:` filter  - indented block of plain Ruby
  #
  # Each tag's body is handed to RuboCop as its own `ProcessedSource` whose
  # offset points at the body's column in the original template. Tags whose
  # body is not valid Ruby on its own are silently skipped (we never want to
  # surface `Lint/Syntax` from a partial Slim fragment).
  module SlimRubyExtractor
    extend TemplateRubyExtractor

    EXPR_LINE   = /\A(?<lead>[ \t]*(?:[a-zA-Z][\w-]*|[.#][^\s=]*)?)==?\s(?<body>.*)$/
    STMT_LINE   = /\A(?<lead>[ \t]*)-\s(?<body>.*)$/
    FILTER_LINE = /\A(?<indent>[ \t]*)ruby:[ \t]*$/

    module_function

    def handles?(path)
      File.extname(path.to_s) == ".slim" && ::Metz::FileClassifier.view?(path)
    end
  end
end
