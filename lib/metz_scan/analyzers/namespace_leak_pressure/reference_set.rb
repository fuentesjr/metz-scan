# frozen_string_literal: true

require_relative "../cross_package_reference_set"

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      class ReferenceSet < CrossPackageReferenceSet
      end
    end
  end
end
