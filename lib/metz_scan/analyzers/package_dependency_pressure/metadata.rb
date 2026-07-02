# frozen_string_literal: true

require_relative "../cross_package_reference_metadata"

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module Metadata
        module_function

        def for(declaration, reference_set, dependency_pressure_category)
          CrossPackageReferenceMetadata.counts(reference_set).merge(
            dependency_metadata(declaration, reference_set, dependency_pressure_category)
          )
        end

        def dependency_metadata(declaration, reference_set, dependency_pressure_category)
          { "declaration" => CrossPackageReferenceMetadata.declaration_metadata(declaration),
            "declared_package" => PackageMap.package_for(declaration.path),
            "project_analyzer_category" => dependency_pressure_category,
            "dependency_pressure_category" => dependency_pressure_category,
            "references" => CrossPackageReferenceMetadata.references_metadata(reference_set) }
        end
      end
    end
  end
end
