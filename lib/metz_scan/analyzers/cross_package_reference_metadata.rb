# frozen_string_literal: true

module MetzScan
  module Analyzers
    module CrossPackageReferenceMetadata
      module_function

      def counts(reference_set)
        { "referring_file_count" => reference_set.files.size,
          "referring_package_count" => reference_set.packages.size,
          "referring_packages" => reference_set.packages,
          "reference_shape" => reference_shape(reference_set) }
      end

      def reference_shape(reference_set)
        { "referring_file_count" => reference_set.files.size,
          "referring_package_count" => reference_set.packages.size,
          "referring_package_roots" => reference_set.package_roots,
          "referring_package_leafs" => reference_set.package_leafs }
      end

      def declaration_metadata(declaration)
        { "name" => declaration.name, "kind" => declaration.kind.to_s, "path" => declaration.path }.compact
      end

      def references_metadata(reference_set)
        reference_set.references.map { |reference| reference_metadata(reference) }
      end

      def reference_metadata(reference)
        { "path" => reference.path, "line" => reference.line, "column" => reference.column,
          "package" => reference.package }.compact
      end
    end
  end
end
