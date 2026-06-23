# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Analyzers
    class ServiceSoup
      class WorkflowCollector
        Workflow = Struct.new(:name, :enclosing_name, :method_name, :path, :line, :expression, :service_calls,
                              keyword_init: true)
        ServiceCall = Struct.new(:service_name, :path, :line, :expression, :style, keyword_init: true)

        def initialize(path)
          @path = path
        end

        def call
          collect_workflows(processed_source.ast, [], [])
        rescue Parser::SyntaxError
          []
        end

        private

        attr_reader :path

        def processed_source
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
        end

        def collect_workflows(node, namespace, workflows)
          return workflows unless node

          collect_node(node, namespace, workflows)
        end

        def collect_node(node, namespace, workflows)
          return collect_namespace(node, namespace, workflows) if %i[class module].include?(node.type)
          return collect_instance_method(node, namespace, workflows) if node.type == :def
          return collect_singleton_method(node, namespace, workflows) if node.type == :defs

          collect_child_workflows(node, namespace, workflows)
        end

        def collect_namespace(node, namespace, workflows)
          name = constant_name(node.children.first)
          body = node.children.last
          collect_workflows(body, namespace + [name].compact, workflows)
        end

        def collect_instance_method(node, namespace, workflows)
          service_calls = service_calls_under(node.children[2])
          workflows << workflow_for(namespace, "##{node.method_name}", node, service_calls) unless service_calls.empty?
          workflows
        end

        def collect_singleton_method(node, namespace, workflows)
          service_calls = service_calls_under(node.children[3])
          workflows << workflow_for(namespace, ".#{node.method_name}", node, service_calls) unless service_calls.empty?
          workflows
        end

        def collect_child_workflows(node, namespace, workflows)
          node.children.grep(RuboCop::AST::Node).each { |child| collect_workflows(child, namespace, workflows) }
          workflows
        end

        def workflow_for(namespace, method_suffix, node, service_calls)
          enclosing_name = namespace.join("::")
          Workflow.new(name: "#{enclosing_name}#{method_suffix}", enclosing_name: optional_name(enclosing_name),
                       method_name: method_suffix, path: path, line: node.loc.expression.line,
                       expression: first_line(node), service_calls: service_calls)
        end

        def service_calls_under(node, service_calls = [])
          return service_calls unless service_search_node?(node)

          collect_service_call(node, service_calls)
          collect_child_service_calls(node, service_calls)
        end

        def nested_scope?(node)
          %i[class module def defs].include?(node.type)
        end

        def service_search_node?(node)
          node && !nested_scope?(node)
        end

        def collect_service_call(node, service_calls)
          service_call = service_call_for(node)
          service_calls << service_call if service_call
        end

        def collect_child_service_calls(node, service_calls)
          node.children.grep(RuboCop::AST::Node).each { |child| service_calls_under(child, service_calls) }
          service_calls
        end

        def service_call_for(node)
          return unless node.type == :send && node.method_name == :call

          service_name, style = service_receiver(node.receiver)
          return unless service_name

          ServiceCall.new(service_name: service_name, path: path, line: node.loc.expression.line,
                          expression: first_line(node), style: style)
        end

        def service_receiver(receiver)
          return [receiver.source, :class_call] if constant_receiver?(receiver)
          return [receiver.receiver.source, :new_call] if new_service_call?(receiver)

          nil
        end

        def new_service_call?(node)
          node&.type == :send && node.method_name == :new && constant_receiver?(node.receiver)
        end

        def constant_receiver?(node)
          node&.type == :const
        end

        def constant_name(node)
          node.source if constant_receiver?(node)
        end

        def optional_name(name)
          name unless name.empty?
        end

        def first_line(node)
          node.loc.expression.source.lines.first.strip
        end
      end
    end
  end
end
