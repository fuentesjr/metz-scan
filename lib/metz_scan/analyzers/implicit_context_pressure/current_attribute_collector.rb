# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      class AmbientContextCollector
        class CurrentAttributeCollector
          include ReferenceMetadata

          ATTRIBUTE_METHOD = /\A[a-z_]\w*=?\z/
          IGNORED_CURRENT_METHODS = %w[after_reset attributes before_reset reset resets set].freeze
          private_constant :ATTRIBUTE_METHOD, :IGNORED_CURRENT_METHODS

          def initialize(path)
            @path = path
          end

          def reference_for(contextual_node)
            node = contextual_node.node
            return unless current_attribute_reference?(node)

            Reference.new(reference_attributes(contextual_node))
          end

          private

          def reference_attributes(contextual_node)
            node = contextual_node.node
            current_attribute_attributes(node)
              .merge(context_attributes(contextual_node))
              .merge(location_attributes(node))
          end

          def current_attribute_attributes(node)
            attribute = attribute_name(node.method_name)
            { ambient_context: "#{node.receiver.source}.#{attribute}", kind: "current_attributes",
              context_key: attribute, attribute: attribute, access_mode: access_mode(node.method_name) }
          end

          def current_attribute_reference?(node)
            node.type == :send && current_receiver?(node.receiver) && attribute_method?(node)
          end

          def current_receiver?(node)
            node&.type == :const && node.source.split("::").last == "Current"
          end

          def attribute_method?(node)
            method_name = node.method_name.to_s
            method_name.match?(ATTRIBUTE_METHOD) && counted_current_method?(method_name, node.arguments)
          end

          def counted_current_method?(method_name, arguments)
            !IGNORED_CURRENT_METHODS.include?(attribute_name(method_name)) &&
              valid_attribute_argument_count?(method_name, arguments)
          end

          def valid_attribute_argument_count?(method_name, arguments)
            method_name.end_with?("=") ? arguments.size == 1 : arguments.empty?
          end

          def attribute_name(method_name)
            method_name.to_s.delete_suffix("=")
          end

          def access_mode(method_name)
            method_name.to_s.end_with?("=") ? "write" : "read"
          end
        end
      end
    end
  end
end
