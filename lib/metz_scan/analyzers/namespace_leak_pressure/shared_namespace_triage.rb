# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      module SharedNamespaceTriage
        CATEGORY = "shared_namespace"
        CONFIDENCE = "low"
        TRIAGE_SEVERITY = "shared namespace"
        TRIAGE_SUMMARY = "Shared namespace signal; review public constants and extension points only when " \
                         "they make app code depend on namespace internals."
        WHY = "Public constants, error families, and framework extension namespaces are often intentional APIs."
        SUGGESTED_NEXT_MOVES = [
          "Leave stable public constants alone when the namespace is the intended API.",
          "Introduce a narrower public object only when callers repeat namespace-specific knowledge."
        ].freeze
        SHARED_SEGMENT_PATTERN =
          /\A(?:Config|Settings?|Core|Events?|Types?|VERSION|DefaultsProvider|RedisKeys|Errors?|Exceptions?)\z/i
        FRAMEWORK_NAMESPACE_PATTERN = /\A(?:I18n::Backend|Spree::Core)\b/
        private_constant :SHARED_SEGMENT_PATTERN, :FRAMEWORK_NAMESPACE_PATTERN

        module_function

        def shared?(declaration)
          shared_name?(declaration.name) || framework_namespace?(declaration.name)
        end

        def attributes(status)
          { project_analyzer_status: status, confidence: CONFIDENCE,
            triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
        end

        def shared_name?(name)
          segments = name.to_s.split("::")
          segments.any? { |segment| segment.match?(SHARED_SEGMENT_PATTERN) } ||
            constant_like_tail?(segments.last) || error_like_tail?(segments.last)
        end

        def framework_namespace?(name)
          name.to_s.match?(FRAMEWORK_NAMESPACE_PATTERN)
        end

        def constant_like_tail?(segment)
          segment.to_s.match?(/\A[A-Z][A-Z0-9_]*\z/)
        end

        def error_like_tail?(segment)
          segment.to_s.match?(/(?:Error|Exception)\z/)
        end
      end
    end
  end
end
