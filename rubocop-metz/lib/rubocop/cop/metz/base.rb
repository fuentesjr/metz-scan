# frozen_string_literal: true

require "rubocop"
require_relative "../../../metz/cop_metadata"
require_relative "on_send_csend_bridge"

module RuboCop
  module Cop
    module Metz
      # Compatibility shim for downstream custom cops. First-party Metz cops
      # inherit directly from RuboCop::Cop::Base and compose Metz helpers
      # explicitly.
      class Base < RuboCop::Cop::Base
        exclude_from_registry

        include ::Metz::CopMetadata
        include OnSendCsendBridge
      end
    end
  end
end
