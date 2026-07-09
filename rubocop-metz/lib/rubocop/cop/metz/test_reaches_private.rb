# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"
require_relative "on_send_csend_bridge"
require_relative "demeter_train_wreck/type_inference"

module RuboCop
  module Cop
    module Metz
      # Flags tests that bypass Ruby visibility with literal `send` calls. This
      # is a mechanism signal only: AST inspection cannot prove the target
      # method is private, so the message stays about interface reach-through.
      class TestReachesPrivate < RuboCop::Cop::Base
        extend ::Metz::CopMetadata
        include OnSendCsendBridge

        BYPASS_METHODS = %i[send __send__].freeze

        MSG = "Test reaches past the public interface with `%<method>s(:%<name>s)`; " \
              "`send` bypasses method visibility — exercise the object through its public API."

        why_it_matters "Tests that reach around the public interface couple to implementation " \
                       "details instead of documenting observable behavior."
        fix_safety :manual
        suggested_next_moves [
          "Exercise the object through its public API.",
          "If the private method deserves its own test, extract it into its own public object.",
          "Add legitimate metaprogramming names to `AllowedMethods`."
        ]

        def on_send(node)
          return unless literal_bypass?(node)
          return if allowed?(node)

          add_offense(node.loc.selector, message: message(node))
        end

        private

        def literal_bypass?(node)
          bypass_send?(node) && literal_name?(method_name_arg(node))
        end

        def bypass_send?(node)
          BYPASS_METHODS.include?(node.method_name)
        end

        def literal_name?(arg)
          arg&.sym_type? || arg&.str_type?
        end

        def allowed?(node)
          allowed_method?(method_name(node)) ||
            operator_method?(method_name(node)) ||
            allowed_receiver?(node)
        end

        def allowed_method?(name)
          allowed_methods.include?(name)
        end

        def operator_method?(name)
          DemeterTrainWreck::TypeInference.operator?(name.to_sym)
        end

        def allowed_receiver?(node)
          receiver = receiver_name(node)
          receiver && allowed_receivers.include?(receiver)
        end

        def message(node)
          format(MSG, method: node.method_name, name: method_name(node))
        end

        def method_name(node)
          method_name_arg(node).value.to_s
        end

        def method_name_arg(node)
          node.arguments.first
        end

        def receiver_name(node)
          receiver = node.receiver
          return nil unless receiver

          receiver.const_type? ? receiver.const_name : receiver.source
        end

        def allowed_methods
          @allowed_methods ||= Array(cop_config["AllowedMethods"]).map(&:to_s)
        end

        def allowed_receivers
          @allowed_receivers ||= Array(cop_config["AllowedReceivers"]).map(&:to_s)
        end
      end
    end
  end
end
