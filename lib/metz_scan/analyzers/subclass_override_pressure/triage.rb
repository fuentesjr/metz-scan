# frozen_string_literal: true

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      module Triage
        CATEGORY_TRIAGE = {
          "abstract_hook_override" => {
            triage_summary: "Candidate abstract hook override signal; review whether subclasses implement an " \
                            "implicit hook protocol.",
            why: "Abstract hooks can make inheritance an implicit protocol whose required behavior is only " \
                 "visible after reading every subclass.",
            suggested_next_moves: [
              "Name the hook contract in the base class or an extracted collaborator.",
              "Keep deliberate extension points when each subclass implements the same stable role."
            ]
          },
          "cooperative_override" => {
            triage_summary: "Candidate cooperative override signal; review whether super-based extension points " \
                            "are explicit.",
            why: "Cooperative overrides rely on template-method ordering, so base changes can break subclasses " \
                 "that extend behavior with super.",
            suggested_next_moves: [
              "Keep cooperative hooks small and document the call order expected around super.",
              "Extract the variable step when subclasses need independent behavior."
            ]
          },
          "replacement_override" => {
            triage_summary: "Candidate replacement override signal; review subclasses that replace concrete " \
                            "base behavior.",
            why: "Replacement overrides can weaken substitution when callers expect the concrete base behavior " \
                 "but subclasses silently replace it.",
            suggested_next_moves: [
              "Prefer composition when subclasses replace the same concrete behavior for different reasons.",
              "Push shared behavior into a collaborator when only the selection logic varies."
            ]
          }
        }.freeze
        MESSAGE_METHODS = {
          "abstract_hook_override" => :abstract_hook_message_for,
          "cooperative_override" => :cooperative_override_message_for,
          "replacement_override" => :replacement_override_message_for
        }.freeze
        private_constant :CATEGORY_TRIAGE, :MESSAGE_METHODS

        def triage_attributes_for(family)
          return broad_root_triage_attributes if family.root_kind

          project_analyzer_triage_attributes.merge(
            triage_summary: triage_profile_for(family).fetch(:triage_summary)
          )
        end

        def project_analyzer_context_attributes(family)
          profile = triage_profile_for(family)

          { project_analyzer_metadata: project_analyzer_metadata_for(family),
            why_it_matters: profile.fetch(:why),
            suggested_next_moves: profile.fetch(:suggested_next_moves) }
        end

        def message_for(family)
          public_send(message_method_for(family), family)
        end

        def broad_root_triage_attributes
          { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: BROAD_ROOT_CONFIDENCE,
            triage_severity: BROAD_ROOT_TRIAGE_SEVERITY, triage_summary: BROAD_ROOT_TRIAGE_SUMMARY }
        end

        def triage_profile_for(family)
          CATEGORY_TRIAGE.fetch(subclass_override_category(family)) { generic_triage_profile }
        end

        def generic_triage_profile
          { triage_summary: TRIAGE_SUMMARY, why: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }
        end

        def message_method_for(family)
          MESSAGE_METHODS.fetch(subclass_override_category(family), :generic_override_message_for)
        end

        def abstract_hook_message_for(family)
          "#{family.base.name} descendants implement #{family.method_name} as an abstract hook in " \
            "#{family.overrides.size} subclasses; consider naming the hook protocol."
        end

        def cooperative_override_message_for(family)
          "#{family.base.name} descendants extend #{family.method_name} with super in " \
            "#{family.overrides_calling_super_count} of #{family.overrides.size} overrides; " \
            "consider making the extension contract explicit."
        end

        def replacement_override_message_for(family)
          "#{family.base.name} descendants replace concrete #{family.method_name} behavior in " \
            "#{family.overrides.size} subclasses; consider whether composition would make the variation explicit."
        end

        def generic_override_message_for(family)
          "#{family.base.name} descendants override #{family.method_name} in #{family.overrides.size} subclasses; " \
            "consider whether the hook protocol should be explicit."
        end
      end
    end
  end
end
