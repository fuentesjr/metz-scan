# frozen_string_literal: true

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      module Metadata
        def triage_attributes_for(root_kind)
          return project_analyzer_triage_attributes unless root_kind

          { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: BROAD_ROOT_CONFIDENCE,
            triage_severity: BROAD_ROOT_TRIAGE_SEVERITY, triage_summary: BROAD_ROOT_TRIAGE_SUMMARY }
        end

        def project_analyzer_context_attributes(family)
          { project_analyzer_metadata: project_analyzer_metadata_for(family),
            why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }
        end

        def message_for(family)
          "#{family.base.name} descendants override #{family.method_name} in #{family.overrides.size} subclasses; " \
            "consider whether the hook protocol should be explicit."
        end

        def project_analyzer_metadata_for(family)
          core_project_analyzer_metadata(family)
            .merge("overriding_descendants" => family.overrides.map(&:owner_name),
                   "override_locations" => override_locations(family.overrides))
            .compact
        end

        def core_project_analyzer_metadata(family)
          { "subclass_override_category" => "subclass_override", "base_name" => family.base.name,
            "method_name" => family.method_name, "root_kind" => family.root_kind,
            "descendant_count" => family.descendants.size, "override_count" => family.overrides.size }
        end

        def override_locations(overrides)
          overrides.map do |declaration|
            { "owner_name" => declaration.owner_name, "path" => declaration.path, "line" => declaration.line }.compact
          end
        end
      end
    end
  end
end
