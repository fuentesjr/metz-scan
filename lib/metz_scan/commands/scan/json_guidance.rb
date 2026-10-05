# frozen_string_literal: true

require_relative "project_analyzer_runner"

module MetzScan
  module Commands
    class Scan
      # Moves each reported cop's default guidance into a top-level `guidance`
      # map keyed by cop_name; offenses keep only the fields that differ.
      module JsonGuidance
        FIELDS = %w[why_it_matters suggested_next_moves fix_safety].freeze
        NO_GUIDANCE = { "why_it_matters" => "", "suggested_next_moves" => [], "fix_safety" => "" }.freeze

        module_function

        def compact!(parsed)
          offenses = parsed["files"].flat_map { |file| file["offenses"] }
          guidance = offenses.map { |offense| offense["cop_name"] }.uniq.to_h { |name| [name, defaults_for(name)] }
          offenses.each { |offense| compact_offense(offense, guidance.fetch(offense["cop_name"])) }
          parsed.merge!("guidance" => guidance)
        end

        def compact_offense(offense, defaults)
          FIELDS.each { |field| offense.delete(field) if offense[field] == defaults.fetch(field) }
        end

        def defaults_for(cop_name)
          analyzer = ProjectAnalyzerRunner::ANALYZERS.find { |candidate| cop_name == candidate::RULE_ID }
          return analyzer_defaults(analyzer) if analyzer

          cop_defaults(RuboCop::Cop::Registry.global.find_by_cop_name(cop_name))
        end

        def analyzer_defaults(analyzer)
          { "why_it_matters" => analyzer::WHY, "suggested_next_moves" => analyzer::SUGGESTED_NEXT_MOVES,
            "fix_safety" => ProjectAnalyzerOffenses::FIX_SAFETY }
        end

        def cop_defaults(cop)
          return NO_GUIDANCE unless cop.respond_to?(:why_it_matters)

          { "why_it_matters" => cop.why_it_matters, "suggested_next_moves" => Array(cop.suggested_next_moves),
            "fix_safety" => cop.fix_safety.to_s }
        end
      end
    end
  end
end
