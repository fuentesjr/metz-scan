# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      module Metadata
        module_function

        def for(declaration, reference_set, namespace_leak_category)
          counts(reference_set.files, reference_set.packages).merge(
            namespace_metadata(declaration, reference_set, namespace_leak_category)
          )
        end

        def namespace_metadata(declaration, reference_set, namespace_leak_category)
          base_namespace_metadata(declaration)
            .merge(category_metadata(namespace_leak_category))
            .merge(references_metadata(reference_set))
        end

        def base_namespace_metadata(declaration)
          { "declaration" => declaration_metadata(declaration),
            "home_namespace" => Namespace.new(declaration.name).home_name,
            "declared_package" => PackageMap.package_for(declaration.path) }
        end

        def category_metadata(namespace_leak_category)
          { "project_analyzer_category" => namespace_leak_category,
            "namespace_leak_category" => namespace_leak_category }
        end

        def references_metadata(reference_set)
          { "references" => reference_set.references.map { |reference| reference_metadata(reference) } }
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
