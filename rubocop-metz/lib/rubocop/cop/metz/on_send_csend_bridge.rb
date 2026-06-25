# frozen_string_literal: true

module RuboCop
  module Cop
    module Metz
      # Gives a cop identical `send` and `csend` dispatch when it defines
      # `on_send`, preserving the project-wide safe-navigation invariant.
      module OnSendCsendBridge
        def self.included(base)
          base.extend(ClassMethods)
          base.alias_method(:on_csend, :on_send) if base.method_defined?(:on_send)
        end

        module ClassMethods
          def method_added(name)
            super
            alias_method(:on_csend, :on_send) if name == :on_send
          end
        end
      end
    end
  end
end
