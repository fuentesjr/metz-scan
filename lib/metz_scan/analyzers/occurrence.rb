# frozen_string_literal: true

module MetzScan
  module Analyzers
    FALLBACK_LINE = 1

    Occurrence = Struct.new(:path, :line, :context, keyword_init: true) do
      def self.from(value, context: nil)
        return value if value.is_a?(self)
        return nil unless value.respond_to?(:path) && value.path

        new(path: value.path, line: line_for(value), context: context)
      end

      def self.line_for(value)
        value.line if value.respond_to?(:line)
      end

      def report_line
        line || MetzScan::Analyzers::FALLBACK_LINE
      end

      def line_source
        line ? "source" : "fallback"
      end
    end
  end
end
