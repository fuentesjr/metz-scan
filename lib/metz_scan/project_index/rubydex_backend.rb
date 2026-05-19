# frozen_string_literal: true

require_relative "rubydex_backend/location_formatting"

module MetzScan
  class ProjectIndex
    class RubydexBackend
      include LocationFormatting

      RUBY_GLOB = "**/*.rb"
      private_constant :RUBY_GLOB

      def self.available?
        require "rubydex"
        true
      rescue LoadError
        false
      end

      def self.unavailable_reason
        "rubydex is not installed; enable the optional rubydex bundle group first"
      end

      def self.build(paths, workspace: false)
        require "rubydex"

        files = ruby_files_for(paths)
        graph = Rubydex::Graph.new(workspace_path: workspace_path_for(paths))
        index_errors = index_graph(graph, files, workspace)

        new(graph: graph, indexed_files: files, index_errors: index_errors)
      end

      def self.index_graph(graph, files, workspace)
        errors = workspace ? graph.index_workspace : graph.index_all(files)
        graph.resolve
        errors
      end
      private_class_method :index_graph

      def self.ruby_files_for(paths)
        paths.flat_map { |path| ruby_files_under(path) }.uniq.sort
      end

      def self.ruby_files_under(path)
        expanded = File.expand_path(path)
        return Dir.glob(File.join(expanded, RUBY_GLOB)) if File.directory?(expanded)
        return [expanded] if File.file?(expanded) && File.extname(expanded) == ".rb"

        []
      end
      private_class_method :ruby_files_under

      def self.workspace_path_for(paths)
        expanded = File.expand_path(paths.first || Dir.pwd)
        return expanded if File.directory?(expanded)

        File.dirname(expanded)
      end
      private_class_method :workspace_path_for

      def initialize(graph:, indexed_files:, index_errors:)
        @graph = graph
        @indexed_files = indexed_files
        @index_errors = Array(index_errors)
      end

      attr_reader :graph, :indexed_files, :index_errors

      def name = :rubydex

      def available? = true

      def reason = nil

      def diagnostics
        graph.diagnostics.to_a
      end

      def declarations
        entries = graph.declarations.map do |declaration|
          Declaration.new(name: declaration.name, path: definition_path(declaration))
        end

        entries.sort_by { |declaration| [declaration.name.to_s, declaration.path.to_s] }
      end

      def documents
        graph.documents.map { |document| path_from_uri(document.uri) }.compact.sort
      end

      def descendants_of(name)
        declaration = graph[name]
        return [] unless declaration.respond_to?(:descendants)

        declaration.descendants.map(&:name).reject { |descendant| descendant == name }.sort
      end

      def constant_references_to(name)
        declaration = graph[name]
        return [] unless declaration.respond_to?(:references)

        declaration.references.map { |reference| normalized_reference(reference) }.compact.sort_by do |reference|
          [reference.path.to_s, reference.line.to_i, reference.column.to_i, reference.name.to_s]
        end
      end

      def search(query)
        graph.search(query).map(&:name).sort
      end

      private

      def definition_path(declaration)
        definition = declaration.definitions.first if declaration.respond_to?(:definitions)
        path_from_location(definition&.location)
      end

      def normalized_reference(reference)
        location = reference.location.to_display
        Reference.new(**reference_attributes(reference, location))
      end

      def reference_attributes(reference, location)
        { name: reference_name(reference), path: path_from_location(location),
          line: location.start_line, column: location.start_column }
      end

      def reference_name(reference)
        return reference.declaration.name if reference.respond_to?(:declaration)
        return reference.name if reference.respond_to?(:name)

        nil
      end
    end
  end
end
