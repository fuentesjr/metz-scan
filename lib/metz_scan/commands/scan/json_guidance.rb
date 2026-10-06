# frozen_string_literal: true

require "rubocop"
require_relative "project_analyzer_runner"

module MetzScan
  module Commands
    class Scan
      # Moves each reported cop's default guidance into a top-level `guidance`
      # map keyed by cop_name; offenses keep only the fields that differ.
      # Under --all-cops, stock RuboCop cops get guidance from the resolved
      # config of the first file reporting them: Description plus autocorrect
      # safety. The default scan never loads the project config for this (see
      # docs/ddrs/2026-07-08-rubocop-scope-only-config.md), so stock cops such
      # as Lint/Syntax keep empty guidance there.
      module JsonGuidance
        FIELDS = %w[why_it_matters suggested_next_moves fix_safety].freeze
        NO_GUIDANCE = { "why_it_matters" => "", "suggested_next_moves" => [], "fix_safety" => "" }.freeze

        module_function

        def compact!(parsed, all_cops:)
          store = RuboCop::ConfigStore.new if all_cops
          guidance = reported_cops(parsed).to_h { |name, path| [name, defaults_for(name, store, path)] }
          parsed["files"].flat_map { |file| file["offenses"] }
                         .each { |offense| compact_offense(offense, guidance.fetch(offense["cop_name"])) }
          parsed.merge!("guidance" => guidance)
        end

        def reported_cops(parsed)
          parsed["files"].flat_map { |file| file["offenses"].map { |offense| [offense["cop_name"], file["path"]] } }
                         .uniq(&:first)
        end

        def compact_offense(offense, defaults)
          FIELDS.each { |field| offense.delete(field) if offense[field] == defaults.fetch(field) }
        end

        def defaults_for(cop_name, store, path)
          analyzer = ProjectAnalyzerRunner::ANALYZERS.find { |candidate| cop_name == candidate::RULE_ID }
          return analyzer_defaults(analyzer) if analyzer

          cop_defaults(RuboCop::Cop::Registry.global.find_by_cop_name(cop_name), store, path)
        end

        def analyzer_defaults(analyzer)
          { "why_it_matters" => analyzer::WHY, "suggested_next_moves" => analyzer::SUGGESTED_NEXT_MOVES,
            "fix_safety" => ProjectAnalyzerOffenses::FIX_SAFETY }
        end

        def cop_defaults(cop, store, path)
          return metz_defaults(cop) if cop.respond_to?(:why_it_matters)
          return NO_GUIDANCE unless cop && store

          stock_defaults(cop, store.for_file(path).for_cop(cop))
        end

        def metz_defaults(cop)
          { "why_it_matters" => cop.why_it_matters, "suggested_next_moves" => Array(cop.suggested_next_moves),
            "fix_safety" => cop.fix_safety.to_s }
        end

        def stock_defaults(cop, config)
          { "why_it_matters" => config["Description"].to_s, "suggested_next_moves" => [],
            "fix_safety" => stock_fix_safety(cop, config) }
        end

        def stock_fix_safety(cop, config)
          return "manual" unless cop.support_autocorrect? && autocorrect_enabled?(config)

          config.fetch("Safe", true) && config.fetch("SafeAutoCorrect", true) ? "safe" : "unsafe"
        end

        # Mirrors RuboCop's Cop::Base#autocorrect_enabled?.
        def autocorrect_enabled?(config)
          !["disabled", false].include?(config["AutoCorrect"])
        end
      end
    end
  end
end
