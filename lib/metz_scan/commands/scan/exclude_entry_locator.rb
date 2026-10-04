# frozen_string_literal: true

require "erb"
require "psych"

module MetzScan
  module Commands
    class Scan
      # Finds where a config file writes one Exclude entry (or a cop's
      # `Enabled` key) and the reason comment documenting it. ERB configs are read as RuboCop renders them;
      # their rendered line numbers do not match the file, so no line is given.
      class ExcludeEntryLocator
        Location = Struct.new(:line, :reason, :reason_status, keyword_init: true)
        UNCHECKED = Location.new(line: nil, reason: nil, reason_status: "unchecked").freeze
        COMMENT_LINE = /\A\s*#/
        TRAILING_COMMENT = /(?:\A|\s)#(.*)\z/

        def initialize(config_path)
          raw = File.read(config_path, encoding: Encoding::UTF_8)
          rendered = Dir.chdir(File.dirname(config_path)) { ERB.new(raw).result }
          @erb = rendered != raw
          @lines = rendered.lines.map(&:chomp)
          @root = Psych.parse(rendered).root
        end

        def locate(key, pattern)
          exclude_key, entry = entry_nodes(key, pattern)
          return UNCHECKED unless entry

          location(entry, entry_reason(entry) || key_reason(exclude_key))
        end

        def locate_enabled(key)
          enabled_key, = mapping_pair(mapping_pair(@root, key)&.last, "Enabled")
          return UNCHECKED unless enabled_key

          location(enabled_key, key_reason(enabled_key))
        end

        private

        def location(node, reason)
          Location.new(line: (node.start_line + 1 unless @erb), reason: reason,
                       reason_status: reason ? "present" : "missing")
        end

        def entry_nodes(key, pattern)
          exclude_key, excludes = mapping_pair(mapping_pair(@root, key)&.last, "Exclude")
          return unless excludes.is_a?(Psych::Nodes::Sequence)

          [exclude_key, excludes.children.find { |node| node.is_a?(Psych::Nodes::Scalar) && node.value == pattern }]
        end

        def mapping_pair(node, key)
          return unless node.is_a?(Psych::Nodes::Mapping)

          node.children.each_slice(2).find { |name, _value| name.is_a?(Psych::Nodes::Scalar) && name.value == key }
        end

        def entry_reason(entry)
          trailing_comment(entry) || comment_block_above(entry.start_line)
        end

        def key_reason(exclude_key)
          trailing_comment(exclude_key) || comment_block_above(exclude_key.start_line)
        end

        def trailing_comment(node)
          comment_text(@lines.fetch(node.end_line)[node.end_column..][TRAILING_COMMENT, 1])
        end

        def comment_block_above(line_index)
          block = @lines.first(line_index).reverse.take_while { |line| line.match?(COMMENT_LINE) }
          comment_text(block.reverse.map { |line| line.sub(COMMENT_LINE, "").strip }.join(" "))
        end

        def comment_text(text)
          stripped = text.to_s.strip
          stripped unless stripped.empty?
        end
      end
    end
  end
end
