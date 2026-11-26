# frozen_string_literal: true

require_relative "../finding"
require_relative "../occurrence"

module MetzScan
  module Analyzers
    class NamespaceLeakPressure
      Finding = Analyzers::Finding.define(:declaration_name, :home_namespace, :declared_package,
                                          :referring_files, :referring_packages, :references,
                                          :primary_location) do
        def report_occurrences
          [Occurrence.from(primary_location, context: declaration_name)].compact
        end
      end
      Location = Struct.new(:name, :path, keyword_init: true)
    end
  end
end
