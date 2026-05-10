# frozen_string_literal: true

require_relative "demeter_train_wreck/type_inference"

module RuboCop
  module Cop
    module Metz
      # Flags Law-of-Demeter-violating object-graph traversal chains while
      # staying quiet on long value-object chains. Walks the send chain
      # downward via `node.receiver`, skipping pass-through methods, allowed
      # constant receivers, and operator/setter sends. Recognises core
      # value-object methods through `TypeInference::METHOD_RETURN_TYPES`
      # and uses a reverse-lookup heuristic on the method name to escape
      # an unknown innermost receiver.
      class DemeterTrainWreck < Base
        MSG = "Object-graph traversal of %<count>d exceeds Max (%<max>d). " \
              "Consider delegating or wrapping intermediate calls."

        why_it_matters "Long object-graph chains tighten coupling and break the Law of Demeter."
        fix_safety :unsafe
        suggested_next_moves [
          "Introduce `delegate :name, to: :account` (or equivalent) to flatten the chain.",
          "Wrap intermediate links in a small query/decorator object that exposes the value you actually need.",
          "Push the behaviour onto the inner collaborator so callers ask for one message instead of traversing four."
        ]

        def on_send(node)
          return if part_of_outer_chain?(node)
          return if outermost_skippable?(node)

          analyze(node)
        end

        private

        def analyze(node)
          links = chain_links(node)
          return if links.size <= max
          return if allowed_receiver_root?(links.first)

          hops = count_graph_traversals(links)
          add_offense(node, message: format(MSG, count: hops, max: max)) if hops > max
        end

        def chain_links(node)
          links = []
          collect_chain(links, node)
          links.reject { |send_node| skip_link?(send_node) }
        end

        def collect_chain(links, start)
          current = start
          while current
            links.unshift(current) if current.type?(:send, :csend)
            current = inner_node(current)
          end
        end

        def inner_node(node)
          return node.receiver if node.type?(:send, :csend)

          node.send_node if node.type?(:block, :numblock, :itblock)
        end

        def skip_link?(send_node)
          operator_send?(send_node) || send_node.setter_method?
        end

        def outermost_skippable?(node)
          operator_send?(node) || node.setter_method?
        end

        def operator_send?(node)
          node.type?(:send, :csend) && TypeInference.operator?(node.method_name)
        end

        def part_of_outer_chain?(node)
          unit = wrapping_block(node) || node
          parent = unit.parent
          parent&.type?(:send, :csend) && parent.receiver.equal?(unit)
        end

        def wrapping_block(node)
          parent = node.parent
          return nil unless parent&.type?(:block, :numblock, :itblock)

          parent.send_node.equal?(node) ? parent : nil
        end

        def count_graph_traversals(links)
          type = infer_initial_type(links.first.receiver)
          hops = 0
          links.each { |send_node| type, hops = advance(type, hops, send_node) }
          hops
        end

        def advance(type, hops, send_node)
          method = send_node.method_name
          return [type, hops] if TypeInference.pass_through?(method)

          resolve(method, type, hops)
        end

        def resolve(method, type, hops)
          next_type = TypeInference.next_type(type, method) ||
                      TypeInference.reverse_lookup(method)
          next_type ? [next_type, hops] : [:unknown, hops + 1]
        end

        def infer_initial_type(node)
          return :unknown if node.nil?

          TypeInference.literal_type(node) || :unknown
        end

        def allowed_receiver_root?(innermost_send)
          receiver = innermost_send.receiver
          return false unless receiver&.const_type?

          allowed_receivers.include?(receiver.const_name)
        end

        def max
          cop_config["Max"] || 4
        end

        def allowed_receivers
          @allowed_receivers ||= Array(cop_config["AllowedReceivers"]).to_set
        end
      end
    end
  end
end
