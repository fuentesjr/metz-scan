# frozen_string_literal: true

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      module Metadata
        def project_analyzer_metadata_for(family)
          core_project_analyzer_metadata(family)
            .merge("overriding_descendants" => family.overrides.map(&:owner_name),
                   "override_locations" => override_locations(family))
            .compact
        end

        def core_project_analyzer_metadata(family)
          category_metadata(subclass_override_category(family)).merge(family_metadata(family))
        end

        def category_metadata(category)
          { "project_analyzer_category" => category, "subclass_override_category" => category }
        end

        def family_metadata(family)
          family_identity_metadata(family)
            .merge(body_fact_metadata(family))
            .merge(count_metadata(family))
        end

        def family_identity_metadata(family)
          { "base_name" => family.base.name, "method_name" => family.method_name, "root_kind" => family.root_kind }
        end

        def body_fact_metadata(family)
          { "base_method_body_kind" => family.base_method_body_kind,
            "overrides_calling_super_count" => family.overrides_calling_super_count }
        end

        def count_metadata(family)
          { "descendant_count" => family.descendants.size, "override_count" => family.overrides.size }
        end

        def override_locations(family)
          family.overrides.map do |declaration|
            { "owner_name" => declaration.owner_name, "path" => declaration.path, "line" => declaration.line,
              "calls_super" => family.override_body_facts.fetch(declaration.owner_name).calls_super }.compact
          end
        end

        def subclass_override_category(family)
          return "broad_root_override" if family.root_kind
          return "abstract_hook_override" if abstract_hook_body?(family.base_method_body_kind)
          return "cooperative_override" if family.overrides_calling_super_count.positive?
          return "replacement_override" unless family.base_method_body_kind == "unknown"

          "subclass_override"
        end

        def abstract_hook_body?(body_kind)
          %w[abstract_raise empty default_value].include?(body_kind)
        end
      end
    end
  end
end
