# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      class AmbientContextCollector
        class ThreadCurrentCollector
          include ReferenceMetadata

          THREAD_KEY_READ = :[]
          THREAD_KEY_WRITE = :[]=
          private_constant :THREAD_KEY_READ, :THREAD_KEY_WRITE

          def initialize(path)
            @path = path
          end

          def reference_for(contextual_node)
            node = contextual_node.node
            return unless thread_current_reference?(node)

            Reference.new(reference_attributes(contextual_node))
          end

          private

          def reference_attributes(contextual_node)
            node = contextual_node.node
            thread_current_attributes(node)
              .merge(context_attributes(contextual_node))
              .merge(location_attributes(node))
          end

          def thread_current_attributes(node)
            { ambient_context: thread_current_context(node), kind: "thread_current",
              context_key: literal_thread_key(node.arguments.first), access_mode: access_mode(node) }
          end

          def thread_current_reference?(node)
            thread_key_access?(node) && thread_current_receiver?(node.receiver) &&
              literal_thread_key(node.arguments.first)
          end

          def thread_key_access?(node)
            return false unless node.type == :send
            return node.arguments.size == 1 if node.method_name == THREAD_KEY_READ
            return node.arguments.size == 2 if node.method_name == THREAD_KEY_WRITE

            false
          end

          def thread_current_receiver?(node)
            node&.type == :send && node.method_name == :current &&
              node.arguments.empty? && thread_constant?(node.receiver)
          end

          def thread_constant?(node)
            node&.type == :const && node.source == "Thread"
          end

          def literal_thread_key(node)
            node.value.to_s if node && %i[sym str].include?(node.type)
          end

          def thread_current_context(node)
            "Thread.current[#{node.arguments.first.source}]"
          end

          def access_mode(node)
            node.method_name == THREAD_KEY_WRITE ? "write" : "read"
          end
        end
      end
    end
  end
end
