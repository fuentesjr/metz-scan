# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      class AmbientContextCollector
        Reference = Struct.new(:ambient_context, :kind, :context_key, :attribute, :access_mode,
                               :enclosing_name, :method_name, :path, :line, :expression,
                               keyword_init: true) do
          def context
            return "#{enclosing_name}#{method_name}" if enclosing_name && method_name

            method_name || enclosing_name
          end
        end

        module ReferenceMetadata
          private

          attr_reader :path

          def context_attributes(contextual_node)
            { enclosing_name: contextual_node.enclosing_name, method_name: contextual_node.method_name }
          end

          def location_attributes(node)
            { path: path, line: node.loc.expression.line, expression: first_line(node) }
          end

          def first_line(node)
            node.loc.expression.source.lines.first.strip
          end
        end
      end
    end
  end
end
