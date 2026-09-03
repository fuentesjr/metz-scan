# frozen_string_literal: true

require_relative "rubydex_backend/file_discovery"
require_relative "rubydex_backend/location_formatting"
require_relative "rubydex_backend/method_declarations"

module MetzScan
  class ProjectIndex
    class RubydexBackend
      include LocationFormatting
      include MethodDeclarations
      extend FileDiscovery

      DECLARATION_KINDS = { "Rubydex::Class" => :class, "Rubydex::Module" => :module }.freeze

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
        # 0.4.0: Config owns workspace_path; Graph.new no longer takes it (Shopify/rubydex#965).
        graph = Rubydex::Graph.configure_for_workspace(workspace_path_for(paths))
        index_errors = index_graph(graph, files, workspace)

        new(graph: graph, indexed_files: files, index_errors: index_errors)
      end

      def self.index_graph(graph, files, workspace)
        errors = workspace ? graph.index_workspace : graph.index_all(files)
        graph.resolve
        errors
      end
      private_class_method :index_graph

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
          Declaration.new(name: declaration.name, path: definition_path(declaration),
                          kind: declaration_kind(declaration))
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
        path_from_display_location(definition)
      end

      def declaration_kind(declaration) = DECLARATION_KINDS[declaration.class.name]

      def path_from_display_location(definition)
        path_from_location(display_location_for(definition))
      end

      def display_location_for(definition)
        location = definition&.location
        return location.to_display if location.respond_to?(:to_display)

        location
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
