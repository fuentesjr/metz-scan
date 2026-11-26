# frozen_string_literal: true

require "rubocop"

require_relative "../source_cache"
require_relative "ambient_context_reference"
require_relative "current_attribute_collector"
require_relative "thread_current_collector"

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      class AmbientContextCollector
        def initialize(path)
          @path = path
        end

        def call
          contextual_nodes.flat_map { |contextual_node| references_for(contextual_node) }
        end

        private

        attr_reader :path

        def references_for(contextual_node)
          reference_collectors.filter_map { |collector| collector.reference_for(contextual_node) }
        end

        def reference_collectors
          [current_attribute_collector, thread_current_collector]
        end

        def current_attribute_collector
          @current_attribute_collector ||= CurrentAttributeCollector.new(path)
        end

        def thread_current_collector
          @thread_current_collector ||= ThreadCurrentCollector.new(path)
        end

        def contextual_nodes
          SourceCache.contextual_nodes(path)
        end
      end
    end
  end
end
