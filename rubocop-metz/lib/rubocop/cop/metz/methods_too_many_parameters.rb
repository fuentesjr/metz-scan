# frozen_string_literal: true

require_relative "base"

module RuboCop
  module Cop
    module Metz
      # Flags methods whose parameter list exceeds the configured `Max`.
      # Counts positional, optional, rest, keyword, and keyword-rest
      # parameters using the same rule as core's `Metrics/ParameterLists`,
      # with a stricter Metz default of 4.
      class MethodsTooManyParameters < Base
        extend RuboCop::ExcludeLimit

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
          count = args_count(node)
          return unless count > max_params

          add_offense(node, message: format(MSG, max: max_params, count: count)) do
            self.max = count
          end
        end

        private

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
