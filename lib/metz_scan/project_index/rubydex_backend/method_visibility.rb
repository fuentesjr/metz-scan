# frozen_string_literal: true

require "rubocop"

module MetzScan
  class ProjectIndex
    class RubydexBackend
      module MethodVisibility
        def visibility_for(declaration, attributes)
          return module_function_visibility(attributes) if module_function_method?(attributes)

          declaration.visibility.to_s
        end

        def module_function_visibility(attributes)
          attributes.fetch(:receiver_kind) == "singleton" ? "public" : "private"
        end

        def module_function_method?(attributes)
          facts = module_function_facts_for(attributes.fetch(:path))
          facts.fetch(module_function_owner_name(attributes.fetch(:owner_name)), [])
               .include?(attributes.fetch(:method_name))
        end

        def module_function_owner_name(owner_name)
          owner_name.to_s.split("::<", 2).first
        end

        def module_function_facts_for(path)
          return {} unless path && File.file?(path)

          @module_function_facts_by_path ||= {}
          @module_function_facts_by_path[path] ||= ModuleFunctionFacts.new(path).to_h
        end

        class ModuleFunctionFacts
          def initialize(path)
            @path = path
          end

          def to_h
            add_scope_tree_facts(ast, [], {})
          rescue Parser::SyntaxError
            {}
          end

          private

          attr_reader :path

          def ast
            processed_source.ast
          end

          def processed_source
            RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
          end

          def add_scope_tree_facts(node, owner_stack, facts)
            return facts unless node
            return add_scope_facts(node, owner_stack, facts) if scope_node?(node)

            add_child_scope_facts(node, owner_stack, facts)
          end

          def add_child_scope_facts(node, owner_stack, facts)
            node&.children&.each do |child|
              add_child_scope_fact(child, owner_stack, facts) if child.is_a?(Parser::AST::Node)
            end

            facts
          end

          def add_child_scope_fact(child, owner_stack, facts)
            return add_scope_facts(child, owner_stack, facts) if scope_node?(child)

            add_child_scope_facts(child, owner_stack, facts)
          end

          def add_scope_facts(scope, owner_stack, facts)
            owner_name = owner_name_for(scope, owner_stack)
            nested_stack = owner_name ? [owner_name] : owner_stack
            add_module_function_facts(facts, owner_name, scope) if owner_name
            add_scope_tree_facts(scope.body, nested_stack, facts)
          end

          def add_module_function_facts(facts, owner_name, scope)
            names = explicit_module_function_names(scope) + default_module_function_names(scope)
            facts[owner_name] = Array(facts[owner_name]) | names unless names.empty?
          end

          def owner_name_for(scope, owner_stack)
            name = scope.identifier.const_name if scope.identifier&.const_type?
            return unless name
            return name if name.include?("::") || owner_stack.empty?

            "#{owner_stack.last}::#{name}"
          end

          def explicit_module_function_names(scope)
            module_function_sends(scope).flat_map { |node| literal_names(node.arguments) }
          end

          def default_module_function_names(scope)
            lines = bare_module_function_lines(scope)
            direct_defs(scope).select { |node| lines.any? { |line| line < node.loc.keyword.line } }
                              .map { |node| node.method_name.to_s }
          end

          def bare_module_function_lines(scope)
            module_function_sends(scope).select { |node| node.arguments.empty? }
                                        .map { |node| node.loc.selector.line }
          end

          def module_function_sends(scope)
            direct_descendants(scope, :send).select do |node|
              !node.receiver && node.method_name == :module_function
            end
          end

          def direct_defs(scope)
            direct_descendants(scope, :def)
          end

          def literal_names(arguments)
            arguments.filter_map { |argument| literal_name(argument) }
          end

          def literal_name(argument)
            argument.value.to_s if argument&.sym_type? || argument&.str_type?
          end

          def direct_descendants(scope, *types)
            scope.each_descendant(*types).reject { |node| nested_scope_between?(node, scope) }
          end

          def nested_scope_between?(node, scope)
            node.each_ancestor.any? do |ancestor|
              break false if ancestor.equal?(scope)

              scope_node?(ancestor)
            end
          end

          def scope_node?(node)
            node&.class_type? || node&.module_type?
          end
        end
      end
    end
  end
end
