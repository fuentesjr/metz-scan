# frozen_string_literal: true

module Metz
  # Turns one Ruby fragment found in a view template into a RuboCop snippet
  # whose offset points back at the fragment inside the template. A control
  # opener (`if cond`, `form_with(...) do |f|`) is not valid Ruby on its own,
  # so it is reduced to the expression it evaluates; any other invalid
  # fragment is skipped so partial template code never surfaces `Lint/Syntax`.
  module TemplateRubyFragment
    CONTROL_CONDITION = /\A(?<prefix>\s*(?:if|unless|while|until|elsif|case)\b\s*)(?<expr>.*?)(?:\s+then)?\s*\z/m
    TRAILING_DO_BLOCK = /\A(?<prefix>\s*)(?<expr>.*?)(?<suffix>\s+do\b(?:\s*\|[^|]*\|)?\s*)\z/m
    MAGIC_COMMENT = "# frozen_string_literal: true\n\n"

    module_function

    def snippet(body, body_offset, processed_source)
      return if body.strip.empty?

      source = parse(body, processed_source)
      return { offset: body_offset, processed_source: source } if source.valid_syntax?

      reduced(body, body_offset, processed_source)
    end

    def valid?(body, processed_source)
      parse(body, processed_source).valid_syntax?
    end

    def reduced(body, body_offset, processed_source)
      match = body.match(CONTROL_CONDITION) || body.match(TRAILING_DO_BLOCK)
      source = match && parse("#{MAGIC_COMMENT}#{match[:expr]}\n", processed_source)
      return unless source&.valid_syntax?

      { offset: body_offset + match.begin(:expr) - MAGIC_COMMENT.length, processed_source: source }
    end

    def empty(processed_source)
      { offset: 0, processed_source: parse("", processed_source) }
    end

    # Cops and their correctors read the config and registry off the
    # ProcessedSource, so each fragment carries the template's.
    def parse(body, processed_source)
      ruby_version = processed_source.ruby_version || RUBY_VERSION.to_f
      RuboCop::ProcessedSource.new(body, ruby_version, processed_source.path).tap do |source|
        source.config = processed_source.config
        source.registry = processed_source.registry
      end
    end
  end
end
