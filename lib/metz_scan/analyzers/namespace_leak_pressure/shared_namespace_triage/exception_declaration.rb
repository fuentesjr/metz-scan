# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      module SharedNamespaceTriage
        class ExceptionDeclaration
          ERROR_SUFFIX_PATTERN = /(?:Error|Exception)\z/
          EXCEPTION_FAMILY_SEGMENT_PATTERN = /(?:Errors?|Exceptions?)\z/i
          STANDARD_EXCEPTION_ROOTS = %w[Exception RuntimeError StandardError].freeze
          private_constant :ERROR_SUFFIX_PATTERN, :EXCEPTION_FAMILY_SEGMENT_PATTERN, :STANDARD_EXCEPTION_ROOTS

          def self.exception?(declaration)
            new(declaration).exception?
          end

          def initialize(declaration)
            @declaration = declaration
          end

          def exception?
            return false unless declaration.path && File.file?(declaration.path)

            exception_node?(processed_source.ast, declaration.name.to_s)
          rescue Parser::SyntaxError, SystemCallError
            false
          end

          private

          attr_reader :declaration

          def processed_source
            RuboCop::ProcessedSource.new(File.read(declaration.path), RUBY_VERSION.to_f)
          end

          def exception_node?(node, name, namespace = [])
            return false unless node
            return module_exception?(node, name, namespace) if node.type == :module
            return class_exception?(node, name, namespace) if node.type == :class
            return assignment_exception?(node, name, namespace) if node.type == :casgn

            child_exception?(node, name, namespace)
          end

          def module_exception?(node, name, namespace)
            exception_node?(node.children.last, name, namespace_for(node.children.first, namespace))
          end

          def class_exception?(node, name, namespace)
            name_node, superclass_node, body = node.children
            return true if constant_name(name_node, namespace) == name && exception_name?(superclass_node&.source)

            exception_node?(body, name, namespace_for(name_node, namespace))
          end

          def assignment_exception?(node, name, namespace)
            assignment_name(node, namespace) == name && class_new_exception?(node.children[2])
          end

          def child_exception?(node, name, namespace)
            node.children.grep(RuboCop::AST::Node).any? { |child| exception_node?(child, name, namespace) }
          end

          def namespace_for(name_node, namespace)
            namespace + constant_segments(name_node)
          end

          def constant_name(name_node, namespace)
            segments = constant_segments(name_node)
            return segments.join("::") if qualified_constant?(name_node)

            (namespace + segments).join("::")
          end

          def assignment_name(node, namespace)
            scope_node, constant_name = node.children
            return (namespace + [constant_name.to_s]).join("::") unless scope_node

            (constant_segments(scope_node) + [constant_name.to_s]).join("::")
          end

          def class_new_exception?(node)
            return false unless node&.type == :send
            return false unless node.receiver&.source == "Class" && node.method_name == :new

            exception_name?(node.arguments.first&.source)
          end

          def exception_name?(name)
            segments = name.to_s.split("::")
            STANDARD_EXCEPTION_ROOTS.include?(segments.last) || error_tail?(segments.last) ||
              segments.any? { |segment| exception_family_segment?(segment) }
          end

          def constant_segments(node)
            node&.source.to_s.sub(/\A::/, "").split("::").reject(&:empty?)
          end

          def qualified_constant?(node)
            node&.source.to_s.include?("::")
          end

          def error_tail?(segment)
            segment.to_s.match?(ERROR_SUFFIX_PATTERN)
          end

          def exception_family_segment?(segment)
            segment.to_s.match?(EXCEPTION_FAMILY_SEGMENT_PATTERN)
          end
        end
      end
    end
  end
end
