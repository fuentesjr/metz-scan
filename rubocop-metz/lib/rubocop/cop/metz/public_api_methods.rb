# frozen_string_literal: true

module RuboCop
  module Cop
    module Metz
      # Collects public method definition nodes on a class body (instance,
      # singleton, and `class << self`), honoring visibility macros via
      # RuboCop's VisibilityHelp. Used by operation / service shape cops.
      class PublicApiMethods
        include VisibilityHelp

        def initialize(class_node, allowed_methods: %i[initialize])
          @class_node = class_node
          @allowed_methods = allowed_methods.map(&:to_sym).freeze
        end

        def names
          definition_nodes.filter_map { |node| public_api_name(node) }
        end

        def count
          names.size
        end

        private

        attr_reader :class_node, :allowed_methods

        def public_api_name(node)
          return unless node_visibility(node) == :public

          name = node.method_name
          return if allowed_methods.include?(name)

          name
        end

        def definition_nodes
          direct_children(class_node).flat_map { |child| definitions_from(child) }
        end

        def definitions_from(node)
          return [node] if node.def_type? || node.defs_type?
          return inline_visibility_defs(node) if visibility_inline_on_def?(node)
          return sclass_definitions(node) if node.sclass_type?

          []
        end

        def inline_visibility_defs(node)
          node.arguments.select { |argument| argument.def_type? || argument.defs_type? }
        end

        def sclass_definitions(sclass_node)
          direct_children(sclass_node).flat_map { |child| definitions_from(child) }
        end

        def direct_children(node)
          body = node.body
          return [] unless body

          body.begin_type? ? body.children.compact : [body]
        end
      end
    end
  end
end
