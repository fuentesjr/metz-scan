# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedBranching
      class PredicateChain
        Result = Struct.new(:decision, :branch_values, keyword_init: true)
        Predicate = Struct.new(:receiver, :method_name, keyword_init: true)

        def initialize(node)
          @node = node
        end

        def call
          predicates = predicate_chain
          return unless same_receiver_chain?(predicates)

          Result.new(decision: predicates.first.receiver, branch_values: predicate_values(predicates))
        end

        private

        attr_reader :node

        def predicate_chain
          if_chain.map { |if_node| predicate_for(if_node.children.first) }
        end

        def if_chain
          chain = []
          chain_if_nodes(node, chain)
          chain
        end

        def chain_if_nodes(node, chain)
          return unless node&.type == :if

          chain << node
          chain_if_nodes(node.children[2], chain)
        end

        def predicate_for(node)
          return unless node&.type == :send && node.receiver && node.method_name.to_s.end_with?("?")

          Predicate.new(receiver: node.receiver.source, method_name: node.method_name.to_s)
        end

        def same_receiver_chain?(predicates)
          predicates.size > 1 && predicates.all? && predicates.map(&:receiver).uniq.one?
        end

        def predicate_values(predicates)
          predicates.map(&:method_name).uniq.sort
        end
      end
    end
  end
end
