# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"

module RuboCop
  module Cop
    module Metz
      # Flags methods whose parameter list exceeds the configured `Max`.
      # Counts positional, optional, rest, keyword, and keyword-rest
      # parameters using the same rule as core's `Metrics/ParameterLists`,
      # with a stricter Metz default of 4.
      class MethodsTooManyParameters < RuboCop::Cop::Base
        extend RuboCop::ExcludeLimit
        extend ::Metz::CopMetadata

        why_it_matters "Long parameter lists hide coupling and make callers responsible for too many decisions."
        fix_safety :manual
        suggested_next_moves [
          "Group related parameters into a parameter object or value object.",
          "Replace flag arguments with separate, well-named methods.",
          "Inject collaborators through the constructor so action methods stay narrow."
        ]

        MSG = "Avoid parameter lists longer than %<max>d parameters. [%<count>d/%<max>d]"

        exclude_limit "Max"

        def on_args(node)
          return unless method_definition_args?(node)

          register_offense(node, args_count(node))
        end

        private

        def register_offense(node, count)
          return unless count > max_params

          add_offense(node, message: format(MSG, max: max_params, count: count)) do
            self.max = count
          end
        end

        def method_definition_args?(node)
          parent = node.parent
          return false unless parent

          parent.def_type? || parent.defs_type?
        end

        def args_count(node)
          node.children.count { |arg| !arg.blockarg_type? }
        end

        def max_params
          cop_config["Max"]
        end
      end
    end
  end
end
