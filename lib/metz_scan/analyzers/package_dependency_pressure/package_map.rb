# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module PackageMap
        IGNORED_REFERENCE_ROOTS = %w[spec test].freeze
        private_constant :IGNORED_REFERENCE_ROOTS

        module_function

        def package_for(path)
          parts = path.to_s.split(File::SEPARATOR)
          return package_after(parts, "app") if parts.include?("app")
          return package_after(parts, "lib") if parts.include?("lib")

          nil
        end

        def ignored_reference_path?(path)
          parts = path.to_s.split(File::SEPARATOR)
          IGNORED_REFERENCE_ROOTS.any? { |root| parts.include?(root) }
        end

        def package_after(parts, root)
          index = parts.index(root)
          return unless parts[index + 1]

          "#{root}/#{parts[index + 1]}"
        end
      end
    end
  end
end
