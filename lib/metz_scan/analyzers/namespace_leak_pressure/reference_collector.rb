# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      class ReferenceCollector
        def initialize(index)
          @index = index
        end

        def for(declaration)
          home_namespace_parts = Namespace.new(declaration.name).home_path_parts
          index.constant_references_to(declaration.name).filter_map do |reference|
            counted_reference_for(reference, declaration.path, home_namespace_parts)
          end
        end

        private

        attr_reader :index

        def counted_reference_for(reference, declaration_path, home_namespace_parts)
          return unless counted_reference?(reference, declaration_path, home_namespace_parts)

          package = PackageMap.package_for(reference.path)
          return unless package

          Reference.new(path: reference.path, line: reference.line, column: reference.column, package: package)
        end

        def counted_reference?(reference, declaration_path, home_namespace_parts)
          !same_path?(reference.path, declaration_path) &&
            !PackageMap.ignored_path?(reference.path) &&
            !inside_home_namespace?(reference.path, home_namespace_parts)
        end

        def inside_home_namespace?(path, home_namespace_parts)
          PackageMap.parts_after_package(path).first(home_namespace_parts.size) == home_namespace_parts
        end

        def same_path?(left, right)
          File.expand_path(left) == File.expand_path(right)
        end

        Reference = Struct.new(:path, :line, :column, :package, keyword_init: true)
        private_constant :Reference
      end
    end
  end
end
