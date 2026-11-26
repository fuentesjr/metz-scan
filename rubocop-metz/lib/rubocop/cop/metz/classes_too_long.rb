# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"

module RuboCop
  module Cop
    module Metz
      # Flags classes whose body exceeds the configured `Max` line count.
      # Wraps the semantics of core's `Metrics/ClassLength` with a stricter
      # default of 100 lines.
      class ClassesTooLong < RuboCop::Cop::Base
        include RuboCop::Cop::CodeLength
        extend ::Metz::CopMetadata

        why_it_matters "Long classes accumulate responsibilities and become hard to change safely."
        fix_safety :manual
        suggested_next_moves [
          "Extract collaborating objects that own a coherent slice of the behavior.",
          "Move data-shaping helpers onto value objects.",
          "Split persistence, presentation, and orchestration concerns into separate classes."
        ]

        MSG = "%<label>s has too many lines. [%<length>d/%<max>d]"

        def on_class(node)
          check_named_length(node, node.identifier.source)
        end

        def on_sclass(node)
          return if node.each_ancestor(:class).any?

          check_named_length(node, nil)
        end

        def on_casgn(node)
          block_node = node.expression || find_expression_within_parent(node.parent)
          return unless class_definition_block?(block_node)

          check_named_length(block_node, casgn_class_name(node))
        end

        def on_block(node)
          return unless class_definition_block?(node) && !casgn_assigned?(node)

          check_named_length(node, nil)
        end
        alias on_numblock on_block
        alias on_itblock on_block

        private

        def class_definition_block?(node)
          node.respond_to?(:class_definition?) && node.class_definition?
        end

        def casgn_assigned?(node)
          parent = node.parent
          return true if parent&.casgn_type? || casgn_compound_assignment?(parent)

          parent&.masgn_type? && parent.lhs.each_child_node(:casgn).any? && parent.expression.equal?(node)
        end

        def casgn_compound_assignment?(node)
          node&.type?(:or_asgn, :and_asgn, :op_asgn) && node.lhs.casgn_type?
        end

        def check_named_length(node, name)
          @target_name = name
          check_code_length(node)
        ensure
          @target_name = nil
        end

        def casgn_class_name(node)
          ns = node.namespace
          return node.name.to_s unless ns

          ns.cbase_type? ? "::#{node.name}" : "#{ns.source}::#{node.name}"
        end

        def cop_label
          @target_name ? "Class `#{@target_name}`" : "Class"
        end

        def message(length, max_length)
          format(MSG, label: cop_label, length: length, max: max_length)
        end

        def find_expression_within_parent(parent)
          if parent&.assignment?
            parent.expression
          elsif parent&.parent&.masgn_type?
            parent.parent.expression
          end
        end
      end
    end
  end
end
