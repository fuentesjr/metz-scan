# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module PackageMap
        IGNORED_REFERENCE_ROOTS = %w[spec test].freeze
        IGNORED_LIB_PACKAGES = %w[generators seed_data seeders tasks test_data].freeze
        private_constant :IGNORED_REFERENCE_ROOTS, :IGNORED_LIB_PACKAGES

        module_function

        def package_for(path)
          parts = path.to_s.split(File::SEPARATOR)
          return package_after(parts, "app") if parts.include?("app")
          return package_after(parts, "lib") if parts.include?("lib")

          nil
        end

        def ignored_path?(path)
          parts = path.to_s.split(File::SEPARATOR)
          ignored_reference_root?(parts) || ignored_lib_package?(parts)
        end

        def package_after(parts, root)
          index = parts.index(root)
          return unless parts[index + 1]

          "#{root}/#{parts[index + 1]}"
        end

        def ignored_reference_root?(parts)
          IGNORED_REFERENCE_ROOTS.any? { |root| parts.include?(root) }
        end

        def ignored_lib_package?(parts)
          index = parts.index("lib")
          index && IGNORED_LIB_PACKAGES.include?(parts[index + 1])
        end
      end
    end
  end
end
