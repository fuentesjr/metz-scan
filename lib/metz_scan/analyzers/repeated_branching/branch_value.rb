# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedBranching
      class BranchValue
        def self.for(condition)
          return literal(condition) if condition.respond_to?(:value)

          new(condition.source, "source:#{condition.source}")
        end

        def self.literal(condition)
          text = condition.type == :sym ? ":#{condition.value}" : condition.value.to_s
          new(text, "#{condition.type}:#{condition.value.inspect}")
        end

        def initialize(text, signature)
          @text = text
          @signature = signature
        end

        attr_reader :text, :signature
      end
    end
  end
end
