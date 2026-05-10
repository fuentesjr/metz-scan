# frozen_string_literal: true

require_relative "base"
require_relative "../../../metz/file_classifier"

module RuboCop
  module Cop
    module Metz
      # Flags Rails controller actions that reach into more than
      # `MaxCollaborators` distinct top-level collaborators. A "direct
      # collaborator" is any constant referenced inside an action body --
      # whether bare (`User`), as the receiver of `.new` (`User.new`), or
      # as the receiver of any other message (`Mailer.confirmation(...)`).
      # Multiple references to the same constant count once. The cop is
      # path-classified through `Metz::FileClassifier.controller?` and is
      # silent on any file that is not under `app/controllers/`.
      class ControllersTooManyDirectCollaborators < Base
        MSG = "Action `%<action>s` reaches into %<count>d direct collaborators (%<list>s); " \
              "Max is %<max>d. Reduce by funneling work through a single coordinator."

        why_it_matters "Controllers that touch many collaborators turn into orchestration soup, " \
                       "hiding intent and resisting change."
        fix_safety :manual
        suggested_next_moves [
          "Introduce a single coordinator/service object that owns the multi-step workflow.",
          "Push side-effecting calls into a service the controller invokes once.",
          "Move auxiliary lookups into model scopes or named queries on the primary resource."
        ]

        def on_def(node)
          collaborators = collect_collaborators(node)
          return if collaborators.size <= max_collaborators

          report_offense(node, collaborators)
        end
        alias on_defs on_def

        def relevant_file?(file)
          return super if file.nil? || file.empty? || file == "(string)"

          ::Metz::FileClassifier.controller?(file)
        end

        private

        def collect_collaborators(method_node)
          method_node.each_descendant(:const).with_object({}) do |const_node, ordered|
            ordered[const_node.const_name] ||= const_node unless nested_inside_const?(const_node)
          end
        end

        def nested_inside_const?(const_node)
          parent = const_node.parent
          parent&.const_type? && parent.children.first.equal?(const_node)
        end

        def report_offense(method_node, collaborators)
          add_offense(collaborators.values.first, message: build_message(method_node, collaborators))
        end

        def build_message(method_node, collaborators)
          format(MSG,
                 action: method_node.method_name,
                 count: collaborators.size,
                 list: collaborators.keys.join(", "),
                 max: max_collaborators)
        end

        def max_collaborators
          cop_config["MaxCollaborators"] || 1
        end
      end
    end
  end
end
