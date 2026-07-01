# frozen_string_literal: true

require_relative "project_analyzer_breakdown"
require_relative "project_analyzer_triage_priority"

module MetzScan
  module Commands
    class Scan
      module ProjectAnalyzerMetadata
        CATEGORY_METADATA_KEYS = %w[
          decision_subject_kind
          dependency_pressure_category
          implicit_context_category
          namespace_leak_category
          repeated_query_category
          root_kind
          subclass_override_category
        ].freeze

        module_function

        def category_metadata_keys = CATEGORY_METADATA_KEYS

        def offense_metadata(finding)
          triage_metadata(finding).merge(analyzer_metadata(finding))
        end

        def summary(findings, offenses)
          rules = rule_summaries(findings, offenses)
          { "finding_count" => findings.size,
            "offense_count" => rules.sum { |rule| rule.fetch("offense_count") },
            "rules" => rules }
        end

        def triage_metadata(finding)
          { "status" => optional_value(finding, :project_analyzer_status),
            "confidence" => optional_value(finding, :confidence),
            "triage_severity" => optional_value(finding, :triage_severity),
            "triage_summary" => optional_value(finding, :triage_summary) }.compact
        end

        def analyzer_metadata(finding)
          return {} unless finding.respond_to?(:project_analyzer_metadata)

          finding.project_analyzer_metadata || {}
        end

        def rule_summaries(findings, offenses)
          findings.group_by(&:rule_id).sort.map do |rule_id, rule_findings|
            rule_summary(rule_id, rule_findings, offenses)
          end
        end

        def rule_summary(rule_id, findings, offenses)
          summary_metadata(findings).merge(rule_count_metadata(rule_id, findings, offenses),
                                           "breakdowns" => ProjectAnalyzerBreakdown.new(findings).to_h)
        end

        def rule_count_metadata(rule_id, findings, offenses)
          { "cop_name" => rule_id, "finding_count" => findings.size,
            "offense_count" => offense_count(rule_id, offenses) }
        end

        def summary_metadata(findings)
          triage_metadata(priority_finding(findings)).slice("status", "confidence", "triage_severity")
        end

        def priority_finding(findings)
          Array(findings).min_by { |finding| ProjectAnalyzerTriagePriority.sort_key(triage_metadata(finding)) }
        end

        def offense_count(rule_id, offenses)
          offenses.count { |offense| offense.fetch("cop_name") == rule_id }
        end

        def optional_value(finding, name)
          finding.public_send(name) if finding.respond_to?(name)
        end
      end
    end
  end
end
