# frozen_string_literal: true

require_relative "../cross_package_reference_metadata"

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      module Metadata
        module_function

        def for(declaration, reference_set, namespace_leak_category)
          CrossPackageReferenceMetadata.counts(reference_set).merge(
            namespace_metadata(declaration, reference_set, namespace_leak_category)
          )
        end

        def namespace_metadata(declaration, reference_set, namespace_leak_category)
          base_namespace_metadata(declaration)
            .merge(category_metadata(namespace_leak_category))
            .merge(references_metadata(reference_set))
        end

        def base_namespace_metadata(declaration)
          { "declaration" => CrossPackageReferenceMetadata.declaration_metadata(declaration),
            "home_namespace" => Namespace.new(declaration.name).home_name,
            "declared_package" => PackageMap.package_for(declaration.path) }
        end

        def category_metadata(namespace_leak_category)
          { "project_analyzer_category" => namespace_leak_category,
            "namespace_leak_category" => namespace_leak_category }
        end

        def references_metadata(reference_set)
          { "references" => CrossPackageReferenceMetadata.references_metadata(reference_set) }
        end
      end
    end
  end
end
