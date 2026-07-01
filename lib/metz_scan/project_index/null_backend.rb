# frozen_string_literal: true

module MetzScan
  class ProjectIndex
    class NullBackend
      def initialize(reason:)
        @reason = reason
      end

      attr_reader :reason

      def name = :null

      def available? = false

      def indexed_files = []

      def index_errors = []

      def diagnostics = []

      def declarations = []

      def method_declarations = []

      def documents = []

      def descendants_of(_name) = []

      def constant_references_to(_name) = []

      def search(_query) = []
    end
  end
end
