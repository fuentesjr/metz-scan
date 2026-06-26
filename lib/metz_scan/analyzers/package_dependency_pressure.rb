# frozen_string_literal: true

require_relative "../project_index"
require_relative "package_dependency_pressure/finding"
require_relative "package_dependency_pressure/metadata"
require_relative "package_dependency_pressure/package_map"
require_relative "package_dependency_pressure/reference_set"
require_relative "package_dependency_pressure/shared_dependency_triage"
require_relative "project_analyzer_triage"

module MetzScan
  module Analyzers
    # Reports declarations referenced from several files outside their package.
    class PackageDependencyPressure
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/PackageDependencyPressure"
      PROJECT_ANALYZER_STATUS = "experimental"
      CONFIDENCE = "early"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Experimental dependency-pressure signal; review broad cross-package references in context."
      WHY = "Cross-package reference pressure can reveal boundaries that many parts of the system depend on."
      SUGGESTED_NEXT_MOVES = [
        "Review whether callers need the full declaration or a narrower interface.",
        "Look for package-specific workflows that could own repeated dependency edges."
      ].freeze
      IGNORED_DECLARATION_NAMES = %w[BasicObject Class Kernel Module Object].freeze
      SYNTHETIC_DECLARATION_MARKER = "::<"
      SUPPORTED_KINDS = [nil, :class, :module].freeze
      private_constant :IGNORED_DECLARATION_NAMES, :SYNTHETIC_DECLARATION_MARKER, :SUPPORTED_KINDS

      def initialize(paths: nil, index: nil, minimum_referring_files: 12, minimum_referring_packages: 5)
        @paths = Array(paths)
        @index = index || ProjectIndex.build(@paths)
        @minimum_referring_files = minimum_referring_files
        @minimum_referring_packages = minimum_referring_packages
      end

      def call
        return [] unless index.available?

        declarations.filter_map { |declaration| finding_for(declaration) }
      end

      private

      attr_reader :paths, :index, :minimum_referring_files, :minimum_referring_packages

      def declarations
        index.declarations.select { |declaration| declaration_candidate?(declaration) }
                          .sort_by { |declaration| declaration.name.to_s }
      end

      def declaration_candidate?(declaration)
        declaration.name&.include?("::") && declaration.path && supported_kind?(declaration) &&
          !ignored_declaration_name?(declaration.name) && !PackageMap.ignored_path?(declaration.path) &&
          PackageMap.package_for(declaration.path)
      end

      def supported_kind?(declaration)
        !declaration.respond_to?(:kind) || SUPPORTED_KINDS.include?(declaration.kind)
      end

      def finding_for(declaration)
        reference_set = ReferenceSet.new(counted_references_for(declaration))
        return unless reference_set.enough?(minimum_referring_files, minimum_referring_packages)

        Finding.new(finding_attributes(declaration, reference_set))
      end

      def counted_references_for(declaration)
        declared_package = PackageMap.package_for(declaration.path)
        index.constant_references_to(declaration.name).filter_map do |reference|
          counted_reference_for(reference, declaration.path, declared_package)
        end
      end

      def counted_reference_for(reference, declaration_path, declared_package)
        return if same_path?(reference.path, declaration_path)
        return if PackageMap.ignored_path?(reference.path)

        package = PackageMap.package_for(reference.path)
        return if !package || package == declared_package

        Reference.new(path: reference.path, line: reference.line, column: reference.column, package: package)
      end

      def finding_attributes(declaration, reference_set)
        core_finding_attributes(declaration, reference_set)
          .merge(triage_attributes_for(declaration),
                 project_analyzer_metadata: metadata_for(declaration, reference_set))
      end

      def core_finding_attributes(declaration, reference_set)
        declared_package = PackageMap.package_for(declaration.path)
        core_identity_attributes(declaration, reference_set, declared_package)
          .merge(core_context_attributes(declaration, reference_set))
      end

      def core_identity_attributes(declaration, reference_set, declared_package)
        { source: source_name, rule_id: RULE_ID,
          message: message_for(declaration, reference_set, declared_package),
          declaration_name: declaration.name, declared_package: declared_package }
      end

      def core_context_attributes(declaration, reference_set)
        { referring_files: reference_set.files,
          referring_packages: reference_set.packages,
          references: reference_set.references,
          primary_location: Location.new(name: declaration.name, path: declaration.path),
          why_it_matters: why_for(declaration), suggested_next_moves: suggested_next_moves_for(declaration) }
      end

      def message_for(declaration, reference_set, declared_package)
        "#{declaration.name} is referenced from #{reference_set.files.size} files across " \
          "#{reference_set.packages.size} packages outside #{declared_package}; " \
          "review whether this boundary is carrying too much dependency pressure."
      end

      def metadata_for(declaration, reference_set)
        Metadata.for(declaration, metadata_context(declaration, reference_set))
      end

      def metadata_context(declaration, reference_set)
        { references: reference_set.references,
          referring_files: reference_set.files,
          referring_packages: reference_set.packages,
          declared_package: PackageMap.package_for(declaration.path),
          dependency_pressure_category: dependency_pressure_category_for(declaration) }
      end

      def same_path?(left, right)
        File.expand_path(left) == File.expand_path(right)
      end

      def ignored_declaration_name?(name)
        IGNORED_DECLARATION_NAMES.include?(name) || name.include?(SYNTHETIC_DECLARATION_MARKER)
      end

      def triage_attributes_for(declaration)
        return SharedDependencyTriage.attributes(PROJECT_ANALYZER_STATUS) if shared_dependency?(declaration)

        project_analyzer_triage_attributes
      end

      def why_for(declaration)
        shared_dependency?(declaration) ? SharedDependencyTriage::WHY : WHY
      end

      def suggested_next_moves_for(declaration)
        shared_dependency?(declaration) ? SharedDependencyTriage::SUGGESTED_NEXT_MOVES : SUGGESTED_NEXT_MOVES
      end

      def dependency_pressure_category_for(declaration)
        shared_dependency?(declaration) ? SharedDependencyTriage::CATEGORY : "package_boundary"
      end

      def shared_dependency?(declaration)
        SharedDependencyTriage.shared?(declaration)
      end

      Reference = Struct.new(:path, :line, :column, :package, keyword_init: true)
      private_constant :Reference
    end
  end
end
