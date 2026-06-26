# frozen_string_literal: true

module MetzScan
  module Analyzers
    class RepeatedBranching
      class DecisionSubject
        GENERIC_SUBJECTS = %w[action key.to_s type value value.to_s].freeze
        SIMPLE_IDENTIFIER = /\A@?[a-z_]\w*(?:\.[a-z_]\w*)?\z/
        private_constant :GENERIC_SUBJECTS, :SIMPLE_IDENTIFIER

        def self.for(decision)
          new(decision)
        end

        def initialize(decision)
          @decision = decision
        end

        attr_reader :decision

        def kind
          return "generic" if GENERIC_SUBJECTS.include?(decision)
          return "state" if SIMPLE_IDENTIFIER.match?(decision)

          "expression"
        end

        def label
          { "generic" => "generic branch subject",
            "state" => "state branch subject",
            "expression" => "expression subject" }.fetch(kind)
        end

        def summary
          { "generic" => "Generic subject; use reported contexts before treating this as design pressure.",
            "state" => "State-like subject; repeated branch tables may describe a shared domain decision.",
            "expression" => "Expression subject; repeated computed conditions may deserve extraction." }.fetch(kind)
        end
      end
    end
  end
end
