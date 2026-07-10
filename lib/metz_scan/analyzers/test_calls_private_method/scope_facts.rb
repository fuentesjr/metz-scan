# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module ScopeFacts
        def assignments_for(scope_node)
          grouped_assignment_owners(scope_node).transform_values { |owners| owners.one? ? owners.first : nil }
        end

        def grouped_assignment_owners(scope_node)
          direct_descendants(scope_node, *ASSIGNMENT_TYPES).each_with_object({}) do |node, grouped|
            record_assignment_owner(grouped, node)
          end
        end

        def record_assignment_owner(grouped, node)
          name = node.children.first.to_s
          grouped[name] ||= []
          grouped[name] << const_new_owner(node.children[1])
        end

        def const_new_owner(node)
          return unless send_like?(node) && node.method_name == :new && node.receiver&.const_type?

          node.receiver.const_name
        end

        def subject_definitions_for(group, sut_name)
          direct_descendants(group, :block).each_with_object({}) do |block, definitions|
            record_subject_definition(definitions, block, sut_name)
          end
        end

        def record_subject_definition(definitions, block, sut_name)
          return unless SUBJECT_DEFINERS.include?(block.send_node.method_name)
          return if block.send_node.receiver

          definitions[subject_name(block.send_node)] = subject_definition_value(block, sut_name)
        end

        def subject_definition_value(block, sut_name)
          subject_body_sut?(block, sut_name) ? :sut : :non_sut
        end

        def subject_body_sut?(block, sut_name)
          sut_name && subject_body_owner(block.body, sut_name) == sut_name
        end

        def subject_body_owner(body, sut_name)
          return unless send_like?(body) && body.method_name == :new
          return body.receiver.const_name if body.receiver&.const_type?

          sut_name if described_class_call?(body.receiver)
        end

        def subject_name(send_node)
          argument = send_node.arguments.first
          argument&.sym_type? ? argument.value : :subject
        end

        def direct_descendants(scope_node, *types)
          scope_node.each_descendant(*types).reject { |node| nested_scope_between?(node, scope_node) }
        end

        def nested_scope_between?(node, scope_node)
          node.each_ancestor.any? do |ancestor|
            break false if ancestor.equal?(scope_node)

            ancestor.class_type? || example_group_block?(ancestor)
          end
        end
      end
    end
  end
end
