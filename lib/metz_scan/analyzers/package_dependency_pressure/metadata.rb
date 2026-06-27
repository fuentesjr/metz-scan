# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module Metadata
        module_function

        def for(declaration, reference_set, dependency_pressure_category)
          counts(reference_set.files, reference_set.packages).merge(
            dependency_metadata(declaration, reference_set, dependency_pressure_category)
          )
        end

        def dependency_metadata(declaration, reference_set, dependency_pressure_category)
          { "declaration" => declaration_metadata(declaration),
            "declared_package" => PackageMap.package_for(declaration.path),
            "dependency_pressure_category" => dependency_pressure_category,
            "references" => references_metadata(reference_set) }
        end

        def references_metadata(reference_set)
          reference_set.references.map { |reference| reference_metadata(reference) }
        end

        def counts(referring_files, referring_packages)
          { "referring_file_count" => referring_files.size,
            "referring_package_count" => referring_packages.size,
            "referring_packages" => referring_packages }
        end

        def declaration_metadata(declaration)
          { "name" => declaration.name, "kind" => declaration.kind.to_s, "path" => declaration.path }.compact
        end

        def reference_metadata(reference)
          { "path" => reference.path, "line" => reference.line, "column" => reference.column,
            "package" => reference.package }.compact
        end
      end
    end
  end
end
