# frozen_string_literal: true

module MetzScan
  module Analyzers
    class InheritanceDescendants
      module RootKind
        FRAMEWORK_ROOT_NAMESPACES = %w[
          ActionCable
          ActionController
          ActionMailer
          ActionView
          ActiveJob
          ActiveModel
          ActiveRecord
          Rails
          ViteRails
        ].freeze
        RAILS_APPLICATION_BASES = %w[ApplicationController ApplicationJob ApplicationMailer ApplicationRecord].freeze
        RULES = [
          ["framework root", lambda { |name|
            FRAMEWORK_ROOT_NAMESPACES.any? { |namespace| name.start_with?("#{namespace}::") }
          }],
          ["rails application base", ->(name) { RAILS_APPLICATION_BASES.include?(name) }],
          ["application job base", lambda { |name|
            name == "Jobs::Base" || name == "Jobs::Scheduled" || name.end_with?("::BaseJob")
          }],
          ["application service base", ->(name) { name == "BaseService" || name.end_with?("::BaseService") }],
          ["controller base", ->(name) { name.end_with?("::BaseController") }],
          ["serializer base", ->(name) { name.end_with?("Serializer") }]
        ].freeze
        private_constant :FRAMEWORK_ROOT_NAMESPACES, :RAILS_APPLICATION_BASES, :RULES

        module_function

        def for(base_name)
          RULES.find { |_label, matcher| matcher.call(base_name) }&.first
        end
      end
    end
  end
end
