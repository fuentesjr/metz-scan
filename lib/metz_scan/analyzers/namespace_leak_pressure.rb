# frozen_string_literal: true

require_relative "../project_index"
require_relative "namespace_leak_pressure/finding"
require_relative "namespace_leak_pressure/metadata"
require_relative "namespace_leak_pressure/namespace"
require_relative "namespace_leak_pressure/reference_collector"
require_relative "namespace_leak_pressure/reference_set"
require_relative "namespace_leak_pressure/shared_namespace_triage"
require_relative "package_map"
require_relative "project_analyzer_triage"

module MetzScan
  module Analyzers
    # Reports internal namespace constants referenced outside their namespace.
    class NamespaceLeakPressure
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/NamespaceLeakPressure"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate namespace-boundary signal; review internal constants used across layers."
      WHY = "Internal namespace constants can become implicit public APIs when distant callers reference them directly."
      SUGGESTED_NEXT_MOVES = [
        "Review whether callers should depend on a narrower public namespace interface.",
        "Look for behavior that belongs behind the namespace boundary instead of in external callers."
      ].freeze
      IGNORED_DECLARATION_NAMES = %w[BasicObject Class Kernel Module Object].freeze
      SYNTHETIC_DECLARATION_MARKER = "::<"
      SUPPORTED_KINDS = [nil, :class, :module].freeze
      private_constant :IGNORED_DECLARATION_NAMES, :SYNTHETIC_DECLARATION_MARKER, :SUPPORTED_KINDS

      def initialize(paths: nil, index: nil, minimum_referring_files: 3, minimum_referring_packages: 3)
        @paths = Array(paths)
        @index = index || ProjectIndex.build(@paths)
        @reference_collector = ReferenceCollector.new(@index)
        @minimum_referring_files = minimum_referring_files
        @minimum_referring_packages = minimum_referring_packages
      end

      def call
        return [] unless index.available?

        declarations.filter_map { |declaration| finding_for(declaration) }
      end

      private

      attr_reader :index, :reference_collector, :minimum_referring_files, :minimum_referring_packages

      def declarations
        index.declarations.select { |declaration| declaration_candidate?(declaration) }
                          .sort_by { |declaration| declaration.name.to_s }
      end

      def declaration_candidate?(declaration)
        declaration.path && Namespace.new(declaration.name).deep? && supported_kind?(declaration) &&
          !ignored_declaration_name?(declaration.name) && !PackageMap.ignored_path?(declaration.path) &&
          PackageMap.package_for(declaration.path)
      end

      def supported_kind?(declaration)
        !declaration.respond_to?(:kind) || SUPPORTED_KINDS.include?(declaration.kind)
      end

      def finding_for(declaration)
        reference_set = ReferenceSet.new(reference_collector.for(declaration))
        return unless reference_set.enough?(minimum_referring_files, minimum_referring_packages)

        Finding.new(finding_attributes(declaration, reference_set))
      end

      def finding_attributes(declaration, reference_set)
        core_finding_attributes(declaration, reference_set)
          .merge(triage_attributes_for(declaration),
                 project_analyzer_metadata: metadata_for(declaration, reference_set))
      end

      def core_finding_attributes(declaration, reference_set)
        identity_attributes(declaration, reference_set)
          .merge(context_attributes(declaration, reference_set))
      end

      def identity_attributes(declaration, reference_set)
        { source: source_name, rule_id: RULE_ID, message: message_for(declaration, reference_set),
          declaration_name: declaration.name, home_namespace: home_namespace_for(declaration.name),
          declared_package: PackageMap.package_for(declaration.path) }
      end

      def context_attributes(declaration, reference_set)
        { referring_files: reference_set.files, referring_packages: reference_set.packages,
          references: reference_set.references,
          primary_location: Location.new(name: declaration.name, path: declaration.path),
          why_it_matters: why_for(declaration), suggested_next_moves: suggested_next_moves_for(declaration) }
      end

      def message_for(declaration, reference_set)
        "#{declaration.name} is referenced from #{reference_set.files.size} files across " \
          "#{reference_set.packages.size} packages outside #{home_namespace_for(declaration.name)}; " \
          "review whether callers know too much about this namespace."
      end

      def metadata_for(declaration, reference_set)
        Metadata.for(declaration, reference_set, namespace_leak_category_for(declaration))
      end

      def home_namespace_for(name)
        Namespace.new(name).home_name
      end

      def triage_attributes_for(declaration)
        return SharedNamespaceTriage.attributes(PROJECT_ANALYZER_STATUS) if shared_namespace?(declaration)

        project_analyzer_triage_attributes
      end

      def namespace_leak_category_for(declaration)
        shared_namespace?(declaration) ? SharedNamespaceTriage::CATEGORY : "namespace_boundary"
      end

      def why_for(declaration)
        shared_namespace?(declaration) ? SharedNamespaceTriage::WHY : WHY
      end

      def suggested_next_moves_for(declaration)
        shared_namespace?(declaration) ? SharedNamespaceTriage::SUGGESTED_NEXT_MOVES : SUGGESTED_NEXT_MOVES
      end

      def shared_namespace?(declaration)
        SharedNamespaceTriage.shared?(declaration)
      end

      def ignored_declaration_name?(name)
        IGNORED_DECLARATION_NAMES.include?(name) || name.include?(SYNTHETIC_DECLARATION_MARKER)
      end
    end
  end
end
