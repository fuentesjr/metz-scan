# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      module Metadata
        module_function

        def for(declaration, context)
          counts(context.fetch(:referring_files), context.fetch(:referring_packages))
            .merge(namespace_metadata(declaration, context))
        end

        def namespace_metadata(declaration, context)
          { "declaration" => declaration_metadata(declaration),
            "home_namespace" => context.fetch(:home_namespace),
            "declared_package" => context.fetch(:declared_package),
            "references" => context.fetch(:references).map { |reference| reference_metadata(reference) } }
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
