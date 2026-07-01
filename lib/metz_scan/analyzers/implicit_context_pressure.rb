# frozen_string_literal: true

require "rubocop"

require_relative "occurrence"
require_relative "package_map"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"

module MetzScan
  module Analyzers
    # Reports repeated ambient CurrentAttributes-style context access.
    class ImplicitContextPressure
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/ImplicitContextPressure"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate ambient context signal; review whether dependencies should be explicit."
      WHY = "Ambient context hides dependencies from method signatures and makes workflows harder to reason about."
      SUGGESTED_NEXT_MOVES = [
        "Pass the context value explicitly into collaborators that use it.",
        "Keep request-scoped globals at application boundaries when possible."
      ].freeze
      MINIMUM_FILES = 3
      MINIMUM_PACKAGES = 2
      Finding = Struct.new(:source, :rule_id, :message, :ambient_context, :referring_files,
                           :referring_packages, :occurrences, :project_analyzer_status, :confidence,
                           :triage_severity, :triage_summary, :project_analyzer_metadata,
                           :why_it_matters, :suggested_next_moves, keyword_init: true) do
        def report_occurrences
          occurrence = occurrences.first
          [Occurrence.from(occurrence, context: occurrence&.context)].compact
        end
      end

      def initialize(paths: nil, index: nil, minimum_files: MINIMUM_FILES, minimum_packages: MINIMUM_PACKAGES)
        @paths = Array(paths)
        @index = index
        @minimum_files = minimum_files
        @minimum_packages = minimum_packages
      end

      def call
        ambient_references.group_by(&:ambient_context).filter_map do |ambient_context, references|
          finding_for(ambient_context, references)
        end
      end

      private

      attr_reader :paths, :index, :minimum_files, :minimum_packages

      def ambient_references
        ruby_files.flat_map { |path| CurrentAttributeCollector.new(path).call }
                  .reject { |reference| PackageMap.ignored_path?(reference.path) }
                  .select { |reference| PackageMap.package_for(reference.path) }
      end

      def ruby_files
        RubyFileEnumerator.new(paths: paths, index: index).call
      end

      def finding_for(ambient_context, references)
        grouped = ReferenceSet.new(references)
        return unless grouped.referring_files.size >= minimum_files
        return unless grouped.referring_packages.size >= minimum_packages

        Finding.new(finding_attributes(ambient_context, grouped))
      end

      def finding_attributes(ambient_context, grouped)
        { source: source_name, rule_id: RULE_ID, message: message_for(ambient_context, grouped),
          ambient_context: ambient_context, referring_files: grouped.referring_files,
          referring_packages: grouped.referring_packages, occurrences: grouped.references,
          project_analyzer_metadata: project_analyzer_metadata_for(ambient_context, grouped),
          why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }.merge(project_analyzer_triage_attributes)
      end

      def message_for(ambient_context, grouped)
        "#{ambient_context} is accessed from #{grouped.referring_files.size} files across " \
          "#{grouped.referring_packages.size} packages; consider passing context explicitly."
      end

      def project_analyzer_metadata_for(ambient_context, grouped)
        { "implicit_context_category" => "current_attributes", "ambient_context" => ambient_context }
          .merge(grouped_metadata(grouped))
      end

      def grouped_metadata(grouped)
        { "access_modes" => grouped.access_modes, "referring_files" => grouped.referring_files,
          "referring_packages" => grouped.referring_packages, "occurrences" => occurrences_metadata(grouped) }
      end

      def occurrences_metadata(grouped)
        grouped.references.map { |reference| reference_metadata(reference) }
      end

      def reference_metadata(reference)
        { "path" => reference.path, "line" => reference.line, "context" => reference.context,
          "expression" => reference.expression, "access_mode" => reference.access_mode }.compact
      end

      class ReferenceSet
        def initialize(references)
          @references = references.sort_by { |reference| [reference.path, reference.line.to_i] }
        end

        attr_reader :references

        def referring_files
          references.map(&:path).uniq
        end

        def referring_packages
          references.map { |reference| PackageMap.package_for(reference.path) }.compact.uniq.sort
        end

        def access_modes
          references.map(&:access_mode).uniq.sort
        end
      end

      class CurrentAttributeCollector
        Reference = Struct.new(:ambient_context, :attribute, :access_mode, :enclosing_name, :method_name,
                               :path, :line, :expression, keyword_init: true) do
          def context
            return "#{enclosing_name}#{method_name}" if enclosing_name && method_name

            method_name || enclosing_name
          end
        end

        ATTRIBUTE_METHOD = /\A[a-z_]\w*=?\z/
        IGNORED_CURRENT_METHODS = %w[after_reset attributes before_reset reset resets set].freeze
        private_constant :ATTRIBUTE_METHOD, :IGNORED_CURRENT_METHODS

        def initialize(path)
          @path = path
        end

        def call
          collect(processed_source.ast, [], nil, [])
        rescue Parser::SyntaxError
          []
        end

        private

        attr_reader :path

        def processed_source
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
        end

        def collect(node, namespace, method_name, references)
          return references unless node
          return collect_namespace(node, namespace, references) if namespace_node?(node)
          return collect_method(node, namespace, method_label(node), references) if method_node?(node)

          collect_reference(node, namespace, method_name, references)
          collect_children(node, namespace, method_name, references)
        end

        def namespace_node?(node)
          %i[class module].include?(node.type)
        end

        def method_node?(node)
          %i[def defs].include?(node.type)
        end

        def method_label(node)
          node.type == :defs ? ".#{node.method_name}" : "##{node.method_name}"
        end

        def collect_namespace(node, namespace, references)
          collect(node.children.last, namespace + [constant_name(node.children.first)].compact, nil, references)
        end

        def collect_method(node, namespace, method_name, references)
          body = node.type == :defs ? node.children[3] : node.children[2]
          collect(body, namespace, method_name, references)
        end

        def collect_reference(node, namespace, method_name, references)
          return unless current_attribute_reference?(node)

          references << reference_for(node, namespace, method_name)
        end

        def collect_children(node, namespace, method_name, references)
          node.children.grep(RuboCop::AST::Node).each { |child| collect(child, namespace, method_name, references) }
          references
        end

        def current_attribute_reference?(node)
          node.type == :send && current_receiver?(node.receiver) && attribute_method?(node)
        end

        def current_receiver?(node)
          node&.type == :const && node.source == "Current"
        end

        def attribute_method?(node)
          method_name = node.method_name.to_s
          method_name.match?(ATTRIBUTE_METHOD) &&
            !IGNORED_CURRENT_METHODS.include?(attribute_name(method_name)) &&
            valid_attribute_argument_count?(method_name, node.arguments)
        end

        def valid_attribute_argument_count?(method_name, arguments)
          return arguments.size == 1 if method_name.end_with?("=")

          arguments.empty?
        end

        def reference_for(node, namespace, method_name)
          attribute = attribute_name(node.method_name)
          Reference.new(ambient_context: "Current.#{attribute}", attribute: attribute,
                        access_mode: access_mode(node.method_name),
                        enclosing_name: optional_name(namespace.join("::")), method_name: method_name,
                        path: path, line: node.loc.expression.line, expression: first_line(node))
        end

        def attribute_name(method_name)
          method_name.to_s.delete_suffix("=")
        end

        def access_mode(method_name)
          method_name.to_s.end_with?("=") ? "write" : "read"
        end

        def constant_name(node)
          node.source if node&.type == :const
        end

        def optional_name(name)
          name unless name.empty?
        end

        def first_line(node)
          node.loc.expression.source.lines.first.strip
        end
      end
    end
  end
end
