# frozen_string_literal: true

module MetzScan
  module Commands
    class Scan
      class ProjectAnalyzerBreakdown
        def initialize(findings)
          @findings = findings
        end

        def to_h
          { "cop_name" => breakdown_for(&:rule_id),
            "confidence" => breakdown_for { |finding| optional_value(finding, :confidence) },
            "triage_severity" => breakdown_for { |finding| optional_value(finding, :triage_severity) },
            "metadata" => metadata_breakdowns }.compact.reject { |_key, values| values.empty? }
        end

        private

        attr_reader :findings

        def metadata_breakdowns
          category_metadata_keys.to_h { |key| [key, metadata_breakdown_for(key)] }
                                .reject { |_key, values| values.empty? }
                                .then { |values| values unless values.empty? }
        end

        def category_metadata_keys
          ProjectAnalyzerMetadata.category_metadata_keys
        end

        def metadata_breakdown_for(key)
          breakdown_for { |finding| analyzer_metadata(finding)[key] }
        end

        def analyzer_metadata(finding)
          return {} unless finding.respond_to?(:project_analyzer_metadata)

          finding.project_analyzer_metadata || {}
        end

        def breakdown_for(&block)
          findings.filter_map { |finding| block.call(finding) }
                  .tally
                  .sort_by { |value, _count| value.to_s }
                  .map { |value, count| { "value" => value, "finding_count" => count } }
        end

        def optional_value(finding, name)
          finding.public_send(name) if finding.respond_to?(name)
        end
      end
    end
  end
end
