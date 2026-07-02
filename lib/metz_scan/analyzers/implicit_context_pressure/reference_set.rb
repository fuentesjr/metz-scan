# frozen_string_literal: true

require_relative "../package_map"

module MetzScan
  module Analyzers
    class ImplicitContextPressure
      class ReferenceSet
        def initialize(references)
          @references = references.sort_by { |reference| [reference.path, reference.line.to_i] }
        end

        attr_reader :references

        def referring_files
          references.map(&:path).uniq
        end

        def referring_packages
          references.map { |reference| PackageMap.package_for(reference.path) }.compact.uniq.sort
        end

        def access_modes
          references.map(&:access_mode).uniq.sort
        end

        def context_kind
          references.first.kind
        end

        def context_key
          references.first.context_key
        end
      end
    end
  end
end
