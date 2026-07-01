# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Analyzers
    class SubclassOverridePressure
      class MethodBodyFacts
        Facts = Struct.new(:body_kind, :calls_super, keyword_init: true)

        def initialize
          @processed_sources = {}
        end

        def for(declaration)
          Facts.new(body_kind: body_kind_for(declaration), calls_super: calls_super?(declaration))
        end

        private

        attr_reader :processed_sources

        def body_kind_for(declaration)
          body_kind_for_node(method_node_for(declaration))
        end

        def body_kind_for_node(node)
          return "unknown" unless node

          body = body_for(node)
          return "empty" unless body

          body_kind_for_body(body)
        end

        def body_kind_for_body(body)
          return "abstract_raise" if abstract_raise?(body)
          return "default_value" if default_value?(body)

          "concrete"
        end

        def calls_super?(declaration)
          body = body_for(method_node_for(declaration))
          body && each_node(body).any? { |node| %i[super zsuper].include?(node.type) }
        end

        def method_node_for(declaration)
          return unless declaration&.path && declaration.line

          ast = processed_source_for(declaration.path)&.ast
          each_node(ast).find { |node| method_node_at_line?(node, declaration.line) }
        end

        def processed_source_for(path)
          return processed_sources[path] if processed_sources.key?(path)

          processed_sources[path] = build_processed_source(path)
        end

        def build_processed_source(path)
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f) if File.file?(path)
        rescue Parser::SyntaxError
          nil
        end

        def method_node_at_line?(node, line)
          %i[def defs].include?(node.type) && node.loc.expression.line == line
        end

        def body_for(node)
          return unless node

          node.type == :def ? node.body : node.children[2]
        end

        def abstract_raise?(body)
          each_node(body).any? { |node| raise_not_implemented?(node) }
        end

        def raise_not_implemented?(node)
          node.type == :send && node.method_name == :raise &&
            node.source.match?(/NotImplemented|must implement|override/i)
        end

        def default_value?(body)
          %i[nil true false str sym array hash].include?(body.type)
        end

        def each_node(root, &block)
          return enum_for(:each_node, root) unless block
          return unless root

          block.call(root)
          root.children.grep(RuboCop::AST::Node).each { |child| each_node(child, &block) }
        end
      end
    end
  end
end
