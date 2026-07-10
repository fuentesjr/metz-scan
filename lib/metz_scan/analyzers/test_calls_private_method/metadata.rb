# frozen_string_literal: true

module MetzScan
  module Analyzers
    class TestCallsPrivateMethod
      module Metadata
        def project_analyzer_metadata_for(site, visibility)
          category_metadata(visibility)
            .merge(identity_metadata(site, visibility))
            .merge("call_site" => { "path" => site.path, "line" => site.line })
        end

        def category_metadata(visibility)
          { "project_analyzer_category" => "test_calls_private_method",
            "test_private_method_category" => "index_confirmed_#{visibility.tr('/', '_')}" }
        end

        def identity_metadata(site, visibility)
          { "owner_name" => site.owner_name, "method_name" => site.method_name,
            "method_identity" => site.method_identity,
            "receiver_kind" => site.receiver_kind,
            "visibility" => visibility }
        end
      end
    end
  end
end
