# frozen_string_literal: true

module MetzScan
  module Analyzers
    class ServiceSoup
      class ServiceCallPattern
        Match = Struct.new(:service_name, :style, keyword_init: true)
        CLASS_SERVICE_METHODS = %i[call].freeze
        NEW_SERVICE_METHOD_STYLES = { call: :new_call, perform: :new_perform }.freeze

        def initialize(node)
          @node = node
        end

        def match
          return class_match if class_service_call?
          return new_match if new_service_call?

          nil
        end

        private

        attr_reader :node

        def class_match
          Match.new(service_name: node.receiver.source, style: :class_call)
        end

        def new_match
          Match.new(service_name: node.receiver.receiver.source,
                    style: NEW_SERVICE_METHOD_STYLES.fetch(node.method_name))
        end

        def class_service_call?
          CLASS_SERVICE_METHODS.include?(node.method_name) && constant_receiver?(node.receiver)
        end

        def new_service_call?
          NEW_SERVICE_METHOD_STYLES.key?(node.method_name) && new_service_receiver?(node.receiver)
        end

        def new_service_receiver?(receiver)
          receiver&.type == :send && receiver.method_name == :new && constant_receiver?(receiver.receiver)
        end

        def constant_receiver?(receiver)
          receiver&.type == :const
        end
      end
    end
  end
end
