# frozen_string_literal: true

require "rubocop"

require_relative "contextual_node_walker"

module MetzScan
  module Analyzers
    # Per-run thread-local cache of parsed RuboCop ASTs and contextual node lists.
    class SourceCache
      CACHE_KEY = :metz_scan_analyzer_source_cache

      def self.with(ruby_version: nil, config_store: nil)
        previous = Thread.current[CACHE_KEY]
        Thread.current[CACHE_KEY] = new(ruby_version: ruby_version, config_store: config_store)
        yield
      ensure
        Thread.current[CACHE_KEY] = previous
      end

      def self.current = Thread.current[CACHE_KEY]

      def self.ast(path) = (current || new).ast(path)

      def self.contextual_nodes(path) = (current || new).contextual_nodes(path)

      def initialize(ruby_version: nil, config_store: nil)
        @ruby_version = ruby_version
        @config_store = config_store
        @sources = {}
        @contextual_nodes = {}
      end

      def processed_source(path)
        return nil unless path && File.file?(path)

        key = File.expand_path(path)
        return @sources[key] if @sources.key?(key)

        @sources[key] = build_processed_source(key)
      end

      def ast(path) = processed_source(path)&.ast

      def contextual_nodes(path)
        return [] unless path

        @contextual_nodes[File.expand_path(path)] ||= build_contextual_nodes(path)
      end

      private

      def build_processed_source(path)
        parse_source(File.read(path), path)
      rescue Parser::SyntaxError, SystemCallError
        nil
      end

      def parse_source(source, path)
        parsed = RuboCop::ProcessedSource.new(source, ruby_version_for(path), path)
        parsed if parsed.valid_syntax?
      end

      def ruby_version_for(path)
        @ruby_version || env_ruby_version || store_ruby_version(path) || RUBY_VERSION.to_f
      end

      def env_ruby_version
        Float(ENV.fetch("RUBOCOP_TARGET_RUBY_VERSION", ""), exception: false)
      end

      def store_ruby_version(path)
        @config_store&.for_file(path)&.target_ruby_version
      rescue RuboCop::Error, Psych::Exception, SystemCallError
        nil
      end

      def build_contextual_nodes(path)
        root = ast(path)
        root ? ContextualNodeWalker.new(root).nodes : []
      end
    end
  end
end
