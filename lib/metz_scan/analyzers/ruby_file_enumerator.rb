# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RubyFileEnumerator
      RUBY_GLOB = "**/*.rb"

      def initialize(paths:, index: nil)
        @paths = Array(paths)
        @index = index
      end

      def call
        return ruby_files_for(paths) unless paths.empty?
        return index.indexed_files if index&.available?

        []
      end

      private

      attr_reader :paths, :index

      def ruby_files_for(paths)
        paths.flat_map { |path| ruby_files_under(path) }.uniq.sort
      end

      def ruby_files_under(path)
        expanded = File.expand_path(path)
        return Dir.glob(File.join(expanded, RUBY_GLOB)) if File.directory?(expanded)
        return [expanded] if File.file?(expanded) && File.extname(expanded) == ".rb"

        []
      end
    end
  end
end
