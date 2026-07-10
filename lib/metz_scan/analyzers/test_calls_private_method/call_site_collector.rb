# frozen_string_literal: true

require_relative "node_predicates"
require_relative "receiver_resolution"
require_relative "scope_facts"
require_relative "scope_resolution"

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      class CallSiteCollector
        include NodePredicates
        include ReceiverResolution
        include ScopeFacts
        include ScopeResolution

        def initialize(path, declarations:)
          @path = path
          @declarations = declarations
        end

        def call
          walk(processed_source.ast, [])
        rescue Parser::SyntaxError
          []
        end

        private

        attr_reader :path, :declarations

        def processed_source
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
        end

        def walk(node, scopes)
          return [] unless node
          return [] if shared_example_group_block?(node)
          return walk(node.body, scopes + [scope_for_block(node, scopes)]) if example_group_block?(node)
          return walk_scoped_node(node, scopes) if scoped_node?(node)

          walk_regular_node(node, scopes)
        end

        def walk_scoped_node(node, scopes)
          scope = node.class_type? ? scope_for_class(node) : scope_for_local(node, scopes)
          walk(node.body, scopes + [scope])
        end

        def walk_regular_node(node, scopes)
          [call_site_for(node, scopes), *walk_child_nodes(node, scopes)].compact
        end

        def walk_child_nodes(node, scopes)
          node.children.grep(RuboCop::AST::Node).flat_map { |child| walk(child, scopes) }
        end

        def call_site_for(node, scopes)
          return unless private_send_call?(node)

          build_call_site(node, literal_method_name(node.arguments.first), receiver_target(node.receiver, scopes))
        end

        def private_send_call?(node)
          send_like?(node) && SEND_METHODS.include?(node.method_name) && literal_method_name(node.arguments.first)
        end

        def build_call_site(node, method_name, receiver)
          return unless receiver

          CallSite.new(path: path, line: node.loc.selector.line, owner_name: receiver.fetch(:owner_name),
                       method_name: method_name, method_identity: method_identity(receiver.fetch(:receiver_kind),
                                                                                  method_name),
                       receiver_kind: receiver.fetch(:receiver_kind))
        end
      end
    end
  end
end
