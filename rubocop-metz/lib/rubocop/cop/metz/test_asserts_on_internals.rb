# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"
require_relative "on_send_csend_bridge"

module RuboCop
  module Cop
    module Metz
      # Flags tests that bind expectations to internal state instead of
      # observable behavior.
      class TestAssertsOnInternals < RuboCop::Cop::Base
        extend ::Metz::CopMetadata
        include OnSendCsendBridge

        INTERNAL_STATE_METHODS = %i[instance_variable_get instance_variable_set].freeze

        MSG = "Test asserts on internal state via `%<method>s`; assert on observable " \
              "behavior through the public interface instead."

        why_it_matters "Tests that bind to implementation state break when safe refactors " \
                       "preserve behavior but change internal representation."
        fix_safety :manual
        suggested_next_moves [
          "Assert on observable behavior through the public interface.",
          "If callers need the value, expose a public reader designed for them.",
          "For controller tests, assert on response or rendered output instead of assigned ivars."
        ]

        def on_send(node)
          return unless internal_state_access?(node)
          return if allowed_receiver?(node)

          add_offense(node.loc.selector, message: message(node))
        end

        private

        def internal_state_access?(node)
          internal_state_method?(node) || receiverless_literal_assigns?(node)
        end

        def internal_state_method?(node)
          INTERNAL_STATE_METHODS.include?(node.method_name)
        end

        def receiverless_literal_assigns?(node)
          receiverless_assigns?(node) && literal_assigns_name?(node.arguments.first)
        end

        def receiverless_assigns?(node)
          node.method_name == :assigns && !node.receiver
        end

        def literal_assigns_name?(arg)
          arg&.sym_type? || arg&.str_type?
        end

        def allowed_receiver?(node)
          receiver = receiver_name(node)
          receiver && allowed_receivers.include?(receiver)
        end

        def message(node)
          format(MSG, method: node.method_name)
        end

        def receiver_name(node)
          receiver = node.receiver
          return nil unless receiver

          receiver.const_type? ? receiver.const_name : receiver.source
        end

        def allowed_receivers
          @allowed_receivers ||= Array(cop_config["AllowedReceivers"]).map(&:to_s)
        end
      end
    end
  end
end
