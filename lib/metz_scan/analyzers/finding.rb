# frozen_string_literal: true

module MetzScan
  module Analyzers
    # Shared base factory for analyzer Finding structs.
    module Finding
      COMMON_FIELDS = %i[
        source rule_id message why_it_matters project_analyzer_status
        confidence triage_severity triage_summary project_analyzer_metadata
        suggested_next_moves
      ].freeze

      def self.define(*extra_fields, &)
        Struct.new(*(COMMON_FIELDS | extra_fields), keyword_init: true, &)
      end
    end
  end
end
