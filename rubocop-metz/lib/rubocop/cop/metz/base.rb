# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"

module RuboCop
  module Cop
    module Metz
      # Shared superclass for every Metz cop. Adds the metadata DSL and
      # transparently aliases `on_csend` to whatever `on_send` a subclass
      # defines, satisfying the project-wide csend invariant.
      class Base < RuboCop::Cop::Base
        include ::Metz::CopMetadata

        class << self
          def method_added(name)
            super
            alias_method(:on_csend, :on_send) if name == :on_send
          end
        end
      end
    end
  end
end
