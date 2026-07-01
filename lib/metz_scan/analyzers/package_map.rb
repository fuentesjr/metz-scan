# frozen_string_literal: true

module MetzScan
  module Analyzers
    # Classifies coarse project packages used by index-backed project analyzers.
    module PackageMap
      IGNORED_REFERENCE_ROOTS = %w[spec test].freeze
      IGNORED_LIB_PACKAGES = %w[generators seed_data seeders tasks test_data].freeze
      IGNORED_SUPPORT_SEGMENTS = %w[seeds testing_support].freeze
      private_constant :IGNORED_REFERENCE_ROOTS, :IGNORED_LIB_PACKAGES, :IGNORED_SUPPORT_SEGMENTS

      module_function

      def package_for(path)
        parts = path.to_s.split(File::SEPARATOR)
        return package_after(parts, app_index(parts)) if app_index(parts)
        return package_after(parts, lib_index(parts)) if lib_index(parts)

        nil
      end

      def ignored_path?(path)
        parts = path.to_s.split(File::SEPARATOR)
        ignored_reference_root?(parts) || ignored_lib_package?(parts) || ignored_support_segment?(parts)
      end

      def parts_after_package(path)
        parts = path.to_s.split(File::SEPARATOR)
        index = app_index(parts) || lib_index(parts)
        return [] unless index

        parts[(index + 2)..] || []
      end

      def package_parts(path)
        package_for(path).to_s.split("/")
      end

      def package_after(parts, index)
        return unless parts[index + 1]

        "#{parts[index]}/#{parts[index + 1]}"
      end

      def ignored_reference_root?(parts)
        index = project_root_index(parts)
        index && IGNORED_REFERENCE_ROOTS.include?(parts[index])
      end

      def ignored_lib_package?(parts)
        index = project_root_index(parts)
        return false unless index && parts[index] == "lib"

        index && IGNORED_LIB_PACKAGES.include?(parts[index + 1])
      end

      def ignored_support_segment?(parts)
        index = app_index(parts) || lib_index(parts)
        return false unless index

        parts[(index + 1)..].any? { |part| IGNORED_SUPPORT_SEGMENTS.include?(part) }
      end

      def app_index(parts)
        parts.rindex("app")
      end

      def lib_index(parts)
        parts.rindex("lib")
      end

      def project_root_index(parts)
        parts.each_index.reverse_each.find { |index| project_root?(parts[index]) }
      end

      def project_root?(part)
        part == "app" || part == "lib" || IGNORED_REFERENCE_ROOTS.include?(part)
      end
    end
  end
end
