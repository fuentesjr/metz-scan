# frozen_string_literal: true

require_relative "template_ruby_extractor"

module Metz
  # Ruby extractor for HAML view templates. Mirrors `Metz::ErbRubyExtractor`:
  # registered with `RuboCop::Runner.ruby_extractors` so view-aware Metz cops
  # (currently `Metz/ViewsDeepNavigation`) can run against HAML content.
  #
  # Recognises the HAML constructs that carry Ruby:
  #
  #   * `= expr`, `!= expr`, `&= expr`, `~ expr` - output script, bare or
  #     after an element (`%p= expr`, `.note{ ... }!= expr`)
  #   * `- stmt`             - silent script, including control openers
  #                            (`- if cond`, `- items.each do |item|`)
  #   * `%p{ key: expr }`    - a single-line Ruby attribute hash
  #   * `:ruby` filter       - indented block of plain Ruby
  #
  # `-#` comments, `==` interpolated text, other filters' bodies (`:css`,
  # `:javascript`, ...), and HTML-style `(...)` or object reference `[...]`
  # attributes are not extracted; output after those attribute groups still
  # is. Every `.haml` file is extracted; each cop's own scope decides which
  # files it checks. Each fragment is handed
  # to RuboCop as its own `ProcessedSource` whose offset points at the
  # fragment's column in the original template; fragments that are not valid
  # Ruby on their own are skipped.
  module HamlRubyExtractor
    extend TemplateRubyExtractor

    SILENT_LINE = /\A[ \t]*-(?!#)[ \t]*(?<body>.*)$/
    ELEMENT     = /\A[ \t]*(?<name>(?:%[\w:-]+)?(?:[.#][\w-]+)*)/
    OUTPUT      = /\G[<>]*(?:[!&]?=|~)(?!=)[ \t]*(?<body>.*)$/
    GROUPS      = { "(" => ")", "[" => "]" }.freeze
    FILTER_LINE = /\A(?<indent>[ \t]*):(?<name>\w+)[ \t]*$/

    module_function

    def handles?(path)
      File.extname(path.to_s) == ".haml"
    end

    def line_fragments(line, processed_source)
      silent = line.match(SILENT_LINE)
      return [[silent[:body], silent.begin(:body)]] if silent

      hashes, stop = element_attributes(line, line.match(ELEMENT), processed_source)
      [*hashes, output(line, stop)].compact
    end

    def element_attributes(line, element, processed_source)
      return [[], element.end(0)] if element[:name].empty?

      attribute_groups(line, element.end(0), processed_source)
    end

    # Walks the `{...}`, `(...)`, and `[...]` groups after an element name and
    # returns the Ruby attribute hashes among them plus the column past them.
    def attribute_groups(line, start, processed_source)
      stop = group_end(line, start, processed_source)
      return [[], start] unless stop

      hashes, past = attribute_groups(line, stop + 1, processed_source)
      hashes.unshift([line[start..stop], start]) if line[start] == "{"
      [hashes, past]
    end

    # The shortest `{...}` that parses as Ruby is a hash; `(...)` and `[...]`
    # end at their balancing bracket.
    def group_end(line, start, processed_source)
      case line[start]
      when "{" then (start...line.length).find { |i| hash_end?(line, start, i, processed_source) }
      when "(", "[" then balanced_end(line, start)
      end
    end

    def hash_end?(line, start, stop, processed_source)
      line[stop] == "}" && TemplateRubyFragment.valid?(line[start..stop], processed_source)
    end

    def balanced_end(line, start)
      steps = { line[start] => 1, GROUPS.fetch(line[start]) => -1 }
      depth = 0
      (start...line.length).find { |i| (depth += steps.fetch(line[i], 0)).zero? }
    end

    def output(line, start)
      match = line.match(OUTPUT, start)
      [match[:body], match.begin(:body)] if match
    end
  end
end
