# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedBranching
      class ContextualNodeWalker
        ContextualNode = Struct.new(:node, :enclosing_name, :method_name, keyword_init: true)

        Context = Struct.new(:namespace, :method_name, keyword_init: true) do
          def self.root = new(namespace: [], method_name: nil)

          def enclosing_name = namespace.join("::").then { |name| name unless name.empty? }

          def with_namespace(name) = self.class.new(namespace: namespace + [name].compact, method_name: nil)

          def with_method(name) = self.class.new(namespace: namespace, method_name: name)
        end

        def initialize(root)
          @root = root
        end

        def nodes
          collect(root, Context.root, [])
        end

        private

        attr_reader :root

        def collect(node, context, nodes)
          return nodes unless node
          return collect_scope(node, context, nodes) if scope_node?(node)

          collect_current(node, context, nodes)
          collect_children(node, context, nodes)
        end

        def collect_scope(node, context, nodes)
          return collect_namespace(node, context, nodes) if namespace_node?(node)
          return collect_method(node, context, nodes) if node.type == :def

          collect_singleton_method(node, context, nodes)
        end

        def collect_namespace(node, context, nodes)
          collect(node.children.last, context.with_namespace(constant_name(node.children.first)), nodes)
        end

        def collect_method(node, context, nodes)
          collect(node.children[2], context.with_method("##{node.method_name}"), nodes)
        end

        def collect_singleton_method(node, context, nodes)
          collect(node.children[3], context.with_method(".#{node.method_name}"), nodes)
        end

        def collect_current(node, context, nodes)
          nodes << ContextualNode.new(node: node, enclosing_name: context.enclosing_name,
                                      method_name: context.method_name)
        end

        def collect_children(node, context, nodes)
          node.children.grep(RuboCop::AST::Node).each { |child| collect(child, context, nodes) }
          nodes
        end

        def scope_node?(node)
          namespace_node?(node) || %i[def defs].include?(node.type)
        end

        def namespace_node?(node)
          %i[class module].include?(node.type)
        end

        def constant_name(node)
          node.source if node&.type == :const
        end
      end
    end
  end
end
