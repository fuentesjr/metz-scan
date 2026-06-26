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
        NAME_SEGMENT_PATTERN =
          /\A(?:Config(?:uration)?|Settings?|Current|Core|Events?|Types?|Feature(?:Flag|Toggle)s?|Permissions?|Utils?|Utilities?)\z/i
        ERROR_SUFFIX_PATTERN = /(?:Error|Exception)\z/
        INFRASTRUCTURE_LIB_SEGMENT_PATTERN =
          /\A(?:cache|caches|errors?|exceptions?|freedom_patches|rate_limiter|redis|scheduler)\z/i
        private_constant :NAME_SEGMENT_PATTERN, :ERROR_SUFFIX_PATTERN, :INFRASTRUCTURE_LIB_SEGMENT_PATTERN

        module_function

        def shared?(declaration)
          shared_name?(declaration.name) || shared_path?(declaration.path)
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
          parts = path.to_s.split(File::SEPARATOR)
          lib_index = parts.index("lib")
          return false unless lib_index

          root_lib_file?(parts, lib_index) || infrastructure_lib_segment?(parts, lib_index)
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

        def root_lib_file?(parts, lib_index)
          parts[lib_index + 1].to_s.end_with?(".rb")
        end

        def infrastructure_lib_segment?(parts, lib_index)
          File.basename(parts[lib_index + 1].to_s, ".rb").match?(INFRASTRUCTURE_LIB_SEGMENT_PATTERN)
        end
      end
    end
  end
end
