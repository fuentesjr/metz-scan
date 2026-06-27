# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      class ReferenceCollector
        def initialize(index)
          @index = index
        end

        def for(declaration)
          declared_package = PackageMap.package_for(declaration.path)
          index.constant_references_to(declaration.name).filter_map do |reference|
            counted_reference_for(reference, declaration.path, declared_package)
          end
        end

        private

        attr_reader :index

        def counted_reference_for(reference, declaration_path, declared_package)
          return if same_path?(reference.path, declaration_path)
          return if PackageMap.ignored_path?(reference.path)

          package = PackageMap.package_for(reference.path)
          return if !package || package == declared_package

          Reference.new(path: reference.path, line: reference.line, column: reference.column, package: package)
        end

        def same_path?(left, right)
          File.expand_path(left) == File.expand_path(right)
        end
      end
    end
  end
end
