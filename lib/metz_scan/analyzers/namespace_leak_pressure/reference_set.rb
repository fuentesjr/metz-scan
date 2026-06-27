# frozen_string_literal: true

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      class ReferenceSet
        def initialize(references)
          @references = references
        end

        attr_reader :references

        def files
          references.map(&:path).uniq.sort
        end

        def packages
          references.map(&:package).uniq.sort
        end

        def enough?(minimum_files, minimum_packages)
          files.size >= minimum_files && packages.size >= minimum_packages
        end
      end
    end
  end
end
