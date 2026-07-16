# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"
require_relative "public_api_methods"

module RuboCop
  module Cop
    module Metz
      # Flags `*Service` classes that expose multiple public methods — the classic
      # god-service / procedural module-with-a-class-wrapper shape
      # (`UserService#create/#update/#notify`).
      #
      # Applies by class name (suffix `Service`), not by path.
      # Full standard: docs/application-operations.md (rule R2) in this repo.
      class GodServiceClass < RuboCop::Cop::Base
        extend ::Metz::CopMetadata

        why_it_matters "A *Service class with many public methods is a procedural " \
                       "namespace, not an object — it scatters use cases and weakens domain modeling."
        fix_safety :manual
        suggested_next_moves [
          "Split each use case into its own thin operation or a method on the owning domain object.",
          "If one real workflow remains, keep a single public entry and privatize helpers.",
          "Drop the Service suffix when the type is a real domain concept with a clear interface."
        ]

        MSG = "%<const>s defines %<count>d public methods (%<names>s); " \
              "god *Service classes should not host multiple use cases " \
              "(max %<max>d public, excluding %<allowed>s)."

        def on_class(node)
          const_name = class_basename(node)
          return unless service_class_name?(const_name)

          public_names = api_names(node)
          return if public_names.size <= max_public_methods

          add_offense(node.identifier, message: offense_message(const_name, public_names))
        end

        private

        def service_class_name?(name)
          return false if name.nil? || name.empty?

          name == "Service" || name.end_with?("Service")
        end

        def class_basename(node)
          const = node.identifier
          return unless const&.const_type?

          const.const_name.to_s.split("::").last
        end

        def api_names(node)
          PublicApiMethods.new(node, allowed_methods: allowed_methods).names
        end

        def offense_message(const_name, public_names)
          format(MSG, **message_fields(const_name, public_names))
        end

        def message_fields(const_name, public_names)
          names = public_names.map(&:inspect).join(", ")
          allowed = allowed_methods.map(&:inspect).join(", ")
          { const: const_name, count: public_names.size, names: names,
            max: max_public_methods, allowed: allowed }
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
