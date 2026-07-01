# frozen_string_literal: true

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      module FamilyBuilder
        private

        def base_candidates
          return configured_base_candidates unless base_names.empty?

          auto_discovered_base_candidates
        end

        def configured_base_candidates
          base_names.filter_map { |name| declarations_by_name[name] }
        end

        def auto_discovered_base_candidates
          index.declarations.select { |declaration| auto_discovered_base_candidate?(declaration) }
        end

        def auto_discovered_base_candidate?(declaration)
          declaration.name && declaration.path && class_candidate?(declaration) &&
            !ignored_declaration_name?(declaration.name)
        end

        def class_candidate?(declaration)
          !declaration.respond_to?(:kind) || declaration.kind.nil? || declaration.kind == :class
        end

        def findings_for(base)
          descendants = sorted_descendants(base.name)
          return [] if descendants.size < minimum_overriding_descendants

          base_methods(base).filter_map { |base_method| finding_for(base, base_method, descendants) }
        end

        def sorted_descendants(base_name)
          index.descendants_of(base_name).reject { |name| ignored_declaration_name?(name) }.sort
        end

        def base_methods(base)
          methods_by_owner.fetch(base.name, []).uniq(&:method_name).sort_by(&:method_name)
        end

        def finding_for(base, base_method, descendants)
          overrides = overrides_for(base_method.method_name, descendants)
          return if overrides.size < minimum_overriding_descendants

          Finding.new(finding_attributes(override_family(base, base_method, descendants, overrides)))
        end

        def overrides_for(method_name, descendants)
          descendants.filter_map { |descendant| method_declaration_for(descendant, method_name) }
                     .sort_by { |declaration| declaration.owner_name.to_s }
        end

        def method_declaration_for(owner_name, method_name)
          methods_by_owner.fetch(owner_name, []).find { |declaration| declaration.method_name == method_name }
        end
      end
    end
  end
end
