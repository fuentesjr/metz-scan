# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module NodePredicates
        def literal_method_name(node)
          node.value.to_s if node&.sym_type? || node&.str_type?
        end

        def described_class_call?(node)
          send_like?(node) && bare_call?(node) && node.method_name == :described_class
        end

        def bare_call?(node)
          !node.receiver && node.arguments.empty?
        end

        def const_name(node)
          node.const_name if node&.const_type?
        end

        def method_identity(receiver_kind, method_name)
          "#{receiver_kind}:#{method_name}"
        end

        def send_like?(node)
          node&.send_type? || node&.csend_type?
        end

        def example_group_block?(node)
          node&.block_type? && group_method?(node, EXAMPLE_GROUP_METHODS)
        end

        def shared_example_group_block?(node)
          node&.block_type? && group_method?(node, SHARED_EXAMPLE_GROUP_METHODS)
        end

        def local_scope_node?(node)
          node&.def_type? || node&.defs_type? || node&.block_type?
        end

        def scoped_node?(node)
          node&.class_type? || local_scope_node?(node)
        end

        def group_method?(node, methods)
          methods.include?(node.send_node.method_name) && example_group_receiver?(node.send_node.receiver)
        end

        def example_group_receiver?(receiver)
          !receiver || (receiver.const_type? && receiver.const_name == "RSpec")
        end
      end
    end
  end
end
