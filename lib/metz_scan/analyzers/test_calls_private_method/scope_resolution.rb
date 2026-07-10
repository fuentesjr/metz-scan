# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module ScopeResolution
        def scope_for_block(node, scopes)
          sut_name = group_sut_name(node) || current_sut_name(scopes)
          Scope.new(kind: :example_group, node: node, sut_name: sut_name,
                    subject_definitions: subject_definitions_for(node, sut_name),
                    assignments: assignments_for(node))
        end

        def scope_for_class(node)
          Scope.new(kind: :class, node: node, sut_name: class_sut_name(node),
                    subject_definitions: {}, assignments: assignments_for(node))
        end

        def scope_for_local(node, scopes)
          Scope.new(kind: :local, node: node, sut_name: current_sut_name(scopes),
                    subject_definitions: {}, assignments: assignments_for(node))
        end

        def group_sut_name(block)
          const_name(block.send_node.arguments.first)
        end

        def class_sut_name(node)
          name = const_name(node.identifier)
          demangled_name_for(name) if name
        end

        def demangled_name_for(test_class_name)
          candidate = demangled_candidate(test_class_name)
          unique_declaration_match(candidate) if candidate
        end

        def demangled_candidate(test_class_name)
          return test_class_name.delete_suffix("Test") if test_class_name.end_with?("Test")

          test_class_name.delete_prefix("Test") if test_class_name.start_with?("Test")
        end

        def unique_declaration_match(candidate)
          matches = declarations.map(&:name).select { |name| name == candidate || name.end_with?("::#{candidate}") }
          matches.one? ? matches.first : nil
        end

        def current_sut_name(scopes)
          scope = scopes.reverse.find { |candidate| SCOPE_KINDS.include?(candidate.kind) }
          scope&.sut_name
        end
      end
    end
  end
end
