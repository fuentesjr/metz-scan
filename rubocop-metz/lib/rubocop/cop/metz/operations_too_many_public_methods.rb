# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/file_classifier"
require_relative "../../../metz/cop_metadata"
require_relative "public_api_methods"

module RuboCop
  module Cop
    module Metz
      # Flags application-operation classes that expose more than one public
      # entry method. Legitimate operations are thin commands with a single
      # intentional API (typically `call` / `perform`), not multi-use bags.
      #
      # Scoped to operation-shaped paths (`app/services/**`, `app/operations/**`).
      # Full standard: docs/application-operations.md (rule R1) in this repo.
      class OperationsTooManyPublicMethods < RuboCop::Cop::Base
        extend ::Metz::CopMetadata

        why_it_matters "Multiple public methods on an operation turn a use-case " \
                       "command into a procedural bag of behaviors and hide missing domain concepts."
        fix_safety :manual
        suggested_next_moves [
          "Keep a single public entry (`call` / `perform`) and make helpers private.",
          "Split unrelated use cases into separate operation classes or domain methods.",
          "Move invariants and calculations onto the objects that own the data."
        ]

        MSG = "Operation defines %<count>d public methods (%<names>s); " \
              "keep a single public entry (max %<max>d, excluding %<allowed>s)."

        def on_class(node)
          return unless operation_file?

          public_names = api_names(node)
          return if public_names.size <= max_public_methods

          add_offense(node.identifier, message: offense_message(public_names))
        end

        private

        def operation_file?
          ::Metz::FileClassifier.operation?(processed_source.file_path)
        end

        def api_names(node)
          PublicApiMethods.new(node, allowed_methods: allowed_methods).names
        end

        def offense_message(public_names)
          format(MSG, **message_fields(public_names))
        end

        def message_fields(public_names)
          names = public_names.map(&:inspect).join(", ")
          allowed = allowed_methods.map(&:inspect).join(", ")
          { count: public_names.size, names: names, max: max_public_methods, allowed: allowed }
        end

        def max_public_methods
          cop_config.fetch("MaxPublicMethods", 1).to_i
        end

        def allowed_methods
          Array(cop_config["AllowedMethods"]).map(&:to_sym)
        end
      end
    end
  end
end
