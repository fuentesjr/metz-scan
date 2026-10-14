# frozen_string_literal: true

module RuboCop
  module Cop
    module Metz
      # Provides the canonical predicates for binary and unary operator method symbols.
      # Extracted from Metz/DemeterTrainWreck's TypeInference module
      # so testing cops can use it without coupling to DemeterTrainWreck.
      module OperatorMethods
        OPERATOR_METHODS = (
          %i[+ - * / % **] +
            %i[== != < > <= >= <=> === =~ !~] +
            %i[& | ^ << >>]
        ).to_set.freeze
        UNARY_OPERATOR_METHODS = %i[! -@ +@ ~].to_set.freeze

        module_function

        def operator?(method)
          OPERATOR_METHODS.include?(method)
        end

        def unary_operator?(method)
          UNARY_OPERATOR_METHODS.include?(method)
        end
      end
    end
  end
end
