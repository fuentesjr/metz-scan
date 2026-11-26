# frozen_string_literal: true

require_relative "../finding"
require_relative "../occurrence"

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      Finding = Analyzers::Finding.define(:path, :line, :owner_name, :method_name, :method_identity,
                                          :receiver_kind, :visibility, :occurrences) do
        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: occurrence_context) }.compact
        end

        def occurrence_context
          "#{owner_name}#{receiver_kind == 'singleton' ? '.' : '#'}#{method_name}"
        end
      end
    end
  end
end
