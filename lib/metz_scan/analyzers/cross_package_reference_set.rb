# frozen_string_literal: true

module MetzScan
  module Analyzers
    class CrossPackageReferenceSet
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

      def package_roots
        packages.map { |package| package.to_s.split("/").first }.uniq.sort
      end

      def package_leafs
        packages.map { |package| package.to_s.split("/").last }.uniq.sort
      end

      def enough?(minimum_files, minimum_packages)
        files.size >= minimum_files && packages.size >= minimum_packages
      end
    end
  end
end
