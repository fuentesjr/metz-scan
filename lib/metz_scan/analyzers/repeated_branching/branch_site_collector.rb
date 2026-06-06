# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Analyzers
    class RepeatedBranching
      class BranchSiteCollector
        BranchSite = Struct.new(:signature, :kind, :decision, :branch_values, :path, :line, :expression,
                                keyword_init: true)
        Predicate = Struct.new(:receiver, :method_name, keyword_init: true)

        def initialize(path)
          @path = path
        end

        def call
          branch_nodes.filter_map { |node| branch_site_for(node) }
        end

        private

        attr_reader :path

        def branch_nodes
          return [] unless File.file?(path)

          walk_nodes(processed_source.ast).select { |node| branch_node?(node) }
        rescue Parser::SyntaxError
          []
        end

        def processed_source
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
        end

        def walk_nodes(node, nodes = [])
          return nodes unless node

          nodes << node
          node.children.grep(RuboCop::AST::Node).each { |child| walk_nodes(child, nodes) }
          nodes
        end

        def branch_node?(node)
          case_branch?(node) || root_if_branch?(node)
        end

        def case_branch?(node)
          node.type == :case && node.children.first
        end

        def root_if_branch?(node)
          node.type == :if && node.loc.respond_to?(:keyword) && node.loc.keyword.source == "if"
        end

        def branch_site_for(node)
          return case_site(node) if case_branch?(node)

          if_site(node)
        end

        def case_site(node)
          decision = node.children.first.source
          values = case_values(node)
          build_site(:case, decision, values, node)
        end

        def case_values(node)
          node.children.grep(RuboCop::AST::WhenNode).flat_map { |when_node| when_values(when_node) }.uniq.sort
        end

        def when_values(when_node)
          when_node.conditions.map { |condition| condition_value(condition) }
        end

        def condition_value(condition)
          return condition.value.to_s if condition.respond_to?(:value)

          condition.source
        end

        def if_site(node)
          predicates = predicate_chain(node)
          return unless same_receiver_chain?(predicates)

          build_site(:if, predicates.first.receiver, predicate_values(predicates), node)
        end

        def predicate_chain(node)
          if_chain(node).map { |if_node| predicate_for(if_node.children.first) }
        end

        def if_chain(node)
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

        def build_site(kind, decision, values, node)
          return if values.empty?

          BranchSite.new(signature: signature_for(kind, decision, values), kind: kind, decision: decision,
                         branch_values: values, path: path, line: node.loc.expression.line,
                         expression: first_line(node))
        end

        def signature_for(kind, decision, values)
          [kind, decision, values].join(":")
        end

        def first_line(node)
          node.loc.expression.source.lines.first.strip
        end
      end
    end
  end
end
