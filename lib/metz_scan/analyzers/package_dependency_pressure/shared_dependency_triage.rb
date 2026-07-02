# frozen_string_literal: true

module MetzScan
  module Analyzers
    class PackageDependencyPressure
      module SharedDependencyTriage
        CATEGORY = "shared_dependency"
        CONFIDENCE = "low"
        TRIAGE_SEVERITY = "shared dependency"
        TRIAGE_SUMMARY = "Shared dependency signal; review broad APIs or infrastructure hubs only when " \
                         "they change often or force package-specific callers to know too much."
        WHY = "Broad shared dependencies are often intentional, but they can still reveal global APIs " \
              "that many packages must understand."
        SUGGESTED_NEXT_MOVES = [
          "Leave stable shared APIs alone when callers use a narrow, intentional interface.",
          "Extract package-owned adapters when broad APIs force repeated package-specific knowledge."
        ].freeze
        SHARED_NAME_SEGMENTS = "Config(?:uration)?|Settings?|Current|Core|Events?|Types?|" \
                               "Feature(?:Flag|Toggle)s?|Permissions?|Utils?|Utilities?"
        NAME_SEGMENT_PATTERN =
          /\A(?:#{SHARED_NAME_SEGMENTS})\z/i
        ERROR_SUFFIX_PATTERN = /(?:Error|Exception)\z/
        INFRASTRUCTURE_LIB_SEGMENT_PATTERN =
          /\A(?:cache|caches|errors?|exceptions?|freedom_patches|rate_limiter|redis|scheduler)\z/i
        VALUE_OBJECT_SEGMENT_PATTERN = /\A(?:Amount|Currency|Money|Price)\z/
        PROTOCOL_MANAGER_SUFFIX_PATTERN = /(?:Manager|Registry|Resolver|Router)\z/
        private_constant :SHARED_NAME_SEGMENTS, :NAME_SEGMENT_PATTERN, :ERROR_SUFFIX_PATTERN,
                         :INFRASTRUCTURE_LIB_SEGMENT_PATTERN, :VALUE_OBJECT_SEGMENT_PATTERN,
                         :PROTOCOL_MANAGER_SUFFIX_PATTERN

        module_function

        def shared?(declaration)
          shared_name?(declaration.name) || shared_path?(declaration.path) || shared_surface?(declaration)
        end

        def attributes(status)
          { project_analyzer_status: status, confidence: CONFIDENCE,
            triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
        end

        def shared_name?(name)
          segments = name_segments(name)
          segments.any? { |segment| segment.match?(NAME_SEGMENT_PATTERN) } ||
            constant_like_tail?(segments.last) || error_like_tail?(segments.last)
        end

        def shared_path?(path)
          package_parts = PackageMap.package_parts(path)
          return false unless package_parts.first == "lib"

          root_lib_file?(package_parts) || infrastructure_lib_segment?(package_parts)
        end

        def shared_surface?(declaration)
          conventional_domain_model?(declaration) ||
            conventional_value_object?(declaration) ||
            protocol_manager_surface?(declaration)
        end

        def name_segments(name)
          name.to_s.split("::")
        end

        def constant_like_tail?(segment)
          segment.to_s.match?(/\A[A-Z][A-Z0-9_]*\z/) && segment.to_s.include?("_")
        end

        def error_like_tail?(segment)
          segment.to_s.match?(ERROR_SUFFIX_PATTERN)
        end

        def root_lib_file?(package_parts)
          package_parts[1].to_s.end_with?(".rb")
        end

        def infrastructure_lib_segment?(package_parts)
          File.basename(package_parts[1].to_s, ".rb").match?(INFRASTRUCTURE_LIB_SEGMENT_PATTERN)
        end

        def conventional_domain_model?(declaration)
          PackageMap.package_for(declaration.path) == "app/models" &&
            conventional_declaration_path?(declaration)
        end

        def conventional_value_object?(declaration)
          PackageMap.package_for(declaration.path).to_s.start_with?("lib/") &&
            name_segments(declaration.name).last.to_s.match?(VALUE_OBJECT_SEGMENT_PATTERN) &&
            conventional_declaration_path?(declaration)
        end

        def protocol_manager_surface?(declaration)
          PackageMap.package_for(declaration.path) == "app/lib" &&
            name_segments(declaration.name).last.to_s.match?(PROTOCOL_MANAGER_SUFFIX_PATTERN) &&
            declaration_path_matches_tail?(declaration)
        end

        def conventional_declaration_path?(declaration)
          normalized_path(declaration.path).end_with?(conventional_path_suffix(declaration.name))
        end

        def declaration_path_matches_tail?(declaration)
          normalized_path(declaration.path).end_with?("#{underscore(name_segments(declaration.name).last)}.rb")
        end

        def conventional_path_suffix(name)
          "#{name_segments(name).map { |segment| underscore(segment) }.join('/')}.rb"
        end

        def underscore(segment)
          segment.to_s
                 .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\\1_\\2')
                 .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
                 .tr("-", "_")
                 .downcase
        end

        def normalized_path(path)
          path.to_s.split(File::SEPARATOR).join("/")
        end
      end
    end
  end
end
