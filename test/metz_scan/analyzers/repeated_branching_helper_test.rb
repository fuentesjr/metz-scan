# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"

require "metz_scan/analyzers/repeated_branching/branch_value"
require "metz_scan/analyzers/repeated_branching/contextual_node_walker"
require "metz_scan/analyzers/repeated_branching/predicate_chain"

module MetzScan
  module Analyzers
    class RepeatedBranchingBranchValueTest < Minitest::Test
      ConditionWithValue = Struct.new(:type, :value, keyword_init: true)
      ConditionWithSource = Struct.new(:source)

      def test_literal_condition_formats_symbol_signature
        condition = ConditionWithValue.new(type: :sym, value: :pending)
        branch_value = RepeatedBranching::BranchValue.literal(condition)

        assert_equal ":pending", branch_value.text
        assert_equal "sym::pending", branch_value.signature
      end

      def test_for_condition_falls_back_to_source
        branch_value = RepeatedBranching::BranchValue.for(ConditionWithSource.new("order.status"))

        assert_equal "order.status", branch_value.text
        assert_equal "source:order.status", branch_value.signature
      end
    end

    class RepeatedBranchingPredicateChainTest < Minitest::Test
      def test_call_requires_single_receiver_chain
        node = parsed_if_node(mixed_receiver_source)

        assert_nil RepeatedBranching::PredicateChain.new(node).call
      end

      def test_call_returns_sorted_branch_values
        node = parsed_if_node(sorted_predicate_source)

        result = RepeatedBranching::PredicateChain.new(node).call
        assert_equal "user", result.decision
        assert_equal %w[admin? manager? staff?], result.branch_values
      end

      def test_call_requires_more_than_one_predicate
        node = parsed_if_node("if user.admin?\n  nil\nend")

        assert_nil RepeatedBranching::PredicateChain.new(node).call
      end

      private

      def mixed_receiver_source
        "if user.admin?\n  nil\nelsif order.manager?\n  nil\nend\n"
      end

      def sorted_predicate_source
        "if user.admin?\n  nil\nelsif user.staff?\n  nil\nelsif user.manager?\n  nil\nend\n"
      end

      def parsed_if_node(source)
        RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
      end
    end

    class RepeatedBranchingContextualNodeWalkerTest < Minitest::Test
      def test_collects_namespace_and_method_contexts
        nodes = RepeatedBranching::ContextualNodeWalker.new(processed_ast(context_source)).nodes

        assert_contexts_for_walker_nodes(nodes)
      end

      private

      def context_source
        <<~RUBY
          module Admin
            class Reports
              DEFAULT = 1

              def execute
                user.admin?
              end

              def self.schedule
                Imap::Service.call
              end
            end
          end
        RUBY
      end

      def assert_contexts_for_walker_nodes(nodes)
        assert_node_context(nodes, "user.admin?", "Admin::Reports", "#execute")
        assert_node_context(nodes, "Imap::Service.call", "Admin::Reports", ".schedule")
        assert_node_context(nodes, "DEFAULT = 1", "Admin::Reports", nil)
      end

      def assert_node_context(nodes, source, enclosing_name, method_name)
        node = node_for(nodes, source)

        assert_equal enclosing_name, node.enclosing_name
        return assert_nil node.method_name unless method_name

        assert_equal method_name, node.method_name
      end

      def processed_ast(source)
        RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f).ast
      end

      def node_for(nodes, source)
        nodes.find { |node| node.node.source == source }
      end
    end
  end
end
