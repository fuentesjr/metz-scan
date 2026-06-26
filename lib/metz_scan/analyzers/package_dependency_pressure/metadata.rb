# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module Metadata
        module_function

        def for(declaration, context)
          counts(context.fetch(:referring_files), context.fetch(:referring_packages)).merge(
            "declaration" => declaration_metadata(declaration),
            "declared_package" => context.fetch(:declared_package),
            "references" => context.fetch(:references).map { |reference| reference_metadata(reference) }
          )
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
