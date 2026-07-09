# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"
require_relative "on_send_csend_bridge"

module RuboCop
  module Cop
    module Metz
      # Flags RSpec expectations that stub or mock the subject under test.
      class TestStubsSubject < RuboCop::Cop::Base
        extend ::Metz::CopMetadata
        include OnSendCsendBridge

        EXAMPLE_GROUP_METHODS = %i[describe context feature example_group xdescribe xcontext
                                   fdescribe fcontext shared_examples shared_examples_for
                                   shared_context].freeze
        SUBJECT_DEFINERS = %i[subject subject!].freeze
        LET_DEFINERS = %i[let let!].freeze
        EXPECTATION_METHODS = %i[expect allow].freeze
        RUNNERS = %i[to to_not not_to].freeze
        STUB_MATCHERS = %i[receive receive_messages receive_message_chain have_received].freeze

        MSG = "Test stubs the subject under test; stub the subject's collaborators, " \
              "not the object whose behavior the test verifies."

        why_it_matters "Tests that stub the subject replace the behavior they claim " \
                       "to verify, so they document implementation setup instead " \
                       "of observable design."
        fix_safety :manual
        suggested_next_moves [
          "Exercise the subject's real behavior; stub only its collaborators.",
          "If a dependency needs controlling, inject and stub the collaborator, not the subject.",
          "If the method you want to stub is doing too much, extract it into a collaborator you can stub honestly."
        ]

        def on_send(node)
          return unless subject_stub_expectation?(node)

          add_offense(node.loc.selector, message: MSG)
        end

        private

        def subject_stub_expectation?(node)
          return false unless RUNNERS.include?(node.method_name)

          subject_name = expectation_subject_name(node.receiver)
          subject_name && in_scope_subject_names(node).include?(subject_name) &&
            node.arguments.any? { |argument| contains_stub_matcher?(argument) }
        end

        def expectation_subject_name(receiver)
          return unless receiver&.send_type?
          return :subject if receiverless_call?(receiver, :is_expected) && receiver.arguments.empty?
          return unless EXPECTATION_METHODS.any? { |method| receiverless_call?(receiver, method) }

          bare_call_name(receiver.arguments.first)
        end

        def bare_call_name(node)
          return unless node&.send_type?
          return if node.receiver

          node.method_name
        end

        def receiverless_call?(node, method_name)
          node.method_name == method_name && !node.receiver
        end

        def contains_stub_matcher?(node)
          node && (stub_matcher?(node) ||
            node.each_descendant(:send).any? { |descendant| stub_matcher?(descendant) })
        end

        def stub_matcher?(node)
          node.send_type? && !node.receiver && STUB_MATCHERS.include?(node.method_name)
        end

        def in_scope_subject_names(node)
          groups = node.each_ancestor(:block).select { |ancestor| example_group_block?(ancestor) }.reverse
          names = groups.reduce([]) { |subject_names, group| fold_subject_names(subject_names, group) }
          names | [:subject]
        end

        def fold_subject_names(names, group)
          (names | subject_names_defined_directly_in(group)) -
            let_override_names_defined_directly_in(group)
        end

        def example_group_block?(node)
          send_node = node.send_node

          EXAMPLE_GROUP_METHODS.include?(send_node.method_name) && example_group_receiver?(send_node.receiver)
        end

        def example_group_receiver?(receiver)
          !receiver || (receiver.const_type? && receiver.const_name == "RSpec")
        end

        def subject_names_defined_directly_in(group)
          group.each_descendant(:block).filter_map do |block|
            next unless nearest_example_group(block) == group
            next unless definer_block?(block, SUBJECT_DEFINERS)

            subject_name(block.send_node)
          end
        end

        def let_override_names_defined_directly_in(group)
          group.each_descendant(:block).filter_map do |block|
            next unless nearest_example_group(block) == group
            next unless definer_block?(block, LET_DEFINERS)

            literal_symbol_name(block.send_node.arguments.first)
          end
        end

        def nearest_example_group(node)
          node.each_ancestor(:block).find { |ancestor| example_group_block?(ancestor) }
        end

        def definer_block?(block, methods)
          methods.include?(block.send_node.method_name) && !block.send_node.receiver
        end

        def subject_name(send_node)
          send_node.arguments.empty? ? :subject : literal_symbol_name(send_node.arguments.first)
        end

        def literal_symbol_name(node)
          node.value if node&.sym_type?
        end
      end
    end
  end
end
