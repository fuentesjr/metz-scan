# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module Triage
        def triage_attributes_for
          project_analyzer_triage_attributes
        end

        def project_analyzer_context_attributes(site, visibility)
          { project_analyzer_metadata: project_analyzer_metadata_for(site, visibility),
            why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }
        end

        def message_for(site, visibility)
          "#{site.owner_name}#{site.receiver_kind == 'singleton' ? '.' : '#'}#{site.method_name} is " \
            "#{visibility}; test behavior through the public interface instead of calling it with send."
        end
      end
    end
  end
end
