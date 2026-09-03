# frozen_string_literal: true

require_relative "demeter_train_wreck"
require_relative "../../../metz/file_classifier"

module RuboCop
  module Cop
    module Metz
      # Flags Rails view templates whose ERB / HAML / SLIM expressions
      # traverse the object graph deeper than `MaxChainLength`. Reuses
      # `Metz/DemeterTrainWreck`'s chain walker and value-object skip logic,
      # so a chain like `name.upcase.strip.split(' ').first` (every link a
      # recognised value-object call) stays silent. Path-classified through
      # `Metz::FileClassifier.view?`: a deep chain inside an `.erb` file
      # outside `app/views/` will not fire.
      # DDR: docs/ddrs/2026-06-24-views-deep-navigation-inherits-demeter.md
      # explains why this specialization uses inheritance instead of composition.
      class ViewsDeepNavigation < DemeterTrainWreck
        include OnSendCsendBridge

        MSG = "View object-graph traversal of %<count>d exceeds MaxChainLength (%<max>d). " \
              "Push the lookup into the controller or expose it via a presenter."

        why_it_matters "Deep object-graph chains in views couple templates to the internal " \
                       "structure of every collaborator they touch, making refactors and " \
                       "test setup painful."
        fix_safety :manual
        suggested_next_moves [
          "Compute the value in the controller and expose it via an instance variable.",
          "Wrap the chain in a presenter or view model that exposes one explicit method.",
          "Use Rails `delegate :foo, to: :collaborator` to flatten the chain at the model boundary."
        ]

        # RuboCop's dispatcher needs the subclass to own the callback, while the
        # inherited implementation remains the shared chain analyzer.
        # rubocop:disable-next Lint/UselessMethodDefinition -- required for subclass callback registration.
        def on_send(node)
          super
        end

        def relevant_file?(file)
          return super if file.nil? || file.empty? || file == "(string)"

          !file_name_matches_any?(file, "Exclude", false) &&
            ::Metz::FileClassifier.view?(file)
        end

        private

        def max
          cop_config["MaxChainLength"] || 3
        end
      end
    end
  end
end
