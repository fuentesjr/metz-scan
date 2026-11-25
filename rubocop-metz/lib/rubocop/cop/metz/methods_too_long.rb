# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"

module RuboCop
  module Cop
    module Metz
      # Flags methods whose body exceeds the configured `Max` line count.
      # Wraps the semantics of core's `Metrics/MethodLength` with a stricter
      # default of 5 lines.
      class MethodsTooLong < RuboCop::Cop::Base
        include RuboCop::Cop::CodeLength
        include RuboCop::Cop::AllowedMethods
        include RuboCop::Cop::AllowedPattern
        extend ::Metz::CopMetadata

        why_it_matters "Long methods hide multiple responsibilities and resist understanding at a glance."
        fix_safety :manual
        suggested_next_moves [
          "Extract cohesive blocks into private helper methods named after their intent.",
          "Replace conditional branches with polymorphism or small lookup objects.",
          "Move data shaping onto value objects or query methods so the action reads as a list of steps."
        ]

        LABEL = "Method"

        def on_def(node)
          return if allowed?(node.method_name)

          check_named_length(node, method_label_name(node))
        end
        alias on_defs on_def

        def on_block(node)
          return unless node.method?(:define_method)

          arg = node.send_node.first_argument
          return if defined_method_allowed?(arg)

          check_named_length(node, define_method_label_name(arg))
        end
        alias on_numblock on_block
        alias on_itblock on_block

        private

        def check_named_length(node, name)
          @target_name = name
          check_code_length(node)
        ensure
          @target_name = nil
        end

        def cop_label
          @target_name ? "Method `#{@target_name}`" : LABEL
        end

        def method_label_name(node)
          node.defs_type? ? "#{node.receiver.source}.#{node.method_name}" : node.method_name.to_s
        end

        def define_method_label_name(arg)
          arg.value.to_s if arg && (arg.sym_type? || arg.str_type?)
        end

        def allowed?(method_name)
          allowed_method?(method_name) || matches_allowed_pattern?(method_name)
        end

        def defined_method_allowed?(method_name)
          method_name.respond_to?(:basic_literal?) &&
            method_name.basic_literal? &&
            allowed?(method_name.value)
        end
      end
    end
  end
end
