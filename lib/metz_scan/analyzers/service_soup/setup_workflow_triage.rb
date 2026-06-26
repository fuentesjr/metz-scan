# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ServiceSoup
      module SetupWorkflowTriage
        CONFIDENCE = "low"
        TRIAGE_SEVERITY = "setup orchestration"
        TRIAGE_SUMMARY = "Setup workflow signal; review only when setup orchestration changes often " \
                         "or hides domain workflow pressure."
        WHY = "Setup orchestration often intentionally runs a list of tasks; review only when it " \
              "changes often or hides domain workflow pressure."
        SUGGESTED_NEXT_MOVES = [
          "Leave setup orchestration as a list when it is stable and declarative.",
          "Extract a named workflow only when setup steps change together or need clearer sequencing."
        ].freeze
        TOKEN_PATTERN = /\A(?:seeds?|seeders?|setup|install(?:er|ation)?|bootstrap)\z/i

        module_function

        def setup?(workflow)
          setup_path?(workflow.path) || setup_name?(workflow.name) || setup_method?(workflow.method_name)
        end

        def attributes(status)
          { project_analyzer_status: status, confidence: CONFIDENCE,
            triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
        end

        def setup_path?(path)
          path.to_s.split(%r{[/\\]}).any? { |segment| setup_token?(File.basename(segment, ".rb")) }
        end

        def setup_name?(name)
          name.to_s.split("::").any? { |segment| setup_token?(segment.delete_prefix("#").delete_prefix(".")) }
        end

        def setup_method?(method_name)
          setup_token?(method_name.to_s.delete_prefix("#").delete_prefix("."))
        end

        def setup_token?(token)
          token.to_s.split(/[_\-.]/).any? { |part| part.match?(TOKEN_PATTERN) }
        end
      end
    end
  end
end
