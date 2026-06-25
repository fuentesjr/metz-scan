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

        MSG = "Class has too many lines. [%<length>d/%<max>d]"

        def on_class(node)
          check_code_length(node)
        end

        def on_sclass(node)
          return if node.each_ancestor(:class).any?

          on_class(node)
        end

        def on_casgn(node)
          block_node = node.expression || find_expression_within_parent(node.parent)
          return unless block_node.respond_to?(:class_definition?) && block_node.class_definition?

          check_code_length(block_node)
        end

        private

        def message(length, max_length)
          format(MSG, length: length, max: max_length)
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
