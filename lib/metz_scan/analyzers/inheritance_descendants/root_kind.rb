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
            name == "Jobs::Base" || name == "Jobs::Scheduled" || name.start_with?("Jobs::") ||
              name.end_with?("Job") || name.end_with?("::BaseJob")
          }],
          ["application service base", lambda { |name|
            name == "BaseService" || name.start_with?("Service::") || name.end_with?("::BaseService") ||
              name.match?(/Base.*Service/) || name.match?(/Service.*Base/)
          }],
          ["controller base", ->(name) { name.end_with?("Controller") }],
          ["serializer base", ->(name) { name.end_with?("Serializer") }],
          ["policy base", ->(name) { name.end_with?("Policy") }],
          ["worker base", ->(name) { name.end_with?("Worker") }],
          ["exception base", lambda { |name|
            name.end_with?("Error") || name.end_with?("Exception") || name.include?("Exception")
          }],
          ["cli base", ->(name) { name.end_with?("CLI::Base") }],
          ["abstract base", lambda { |name|
            name.include?("::Base::") || base_token?(name.split("::").last)
          }]
        ].freeze
        private_constant :FRAMEWORK_ROOT_NAMESPACES, :RAILS_APPLICATION_BASES, :RULES

        module_function

        def for(base_name)
          RULES.find { |_label, matcher| matcher.call(base_name) }&.first
        end

        def base_token?(name)
          name == "Base" || name.start_with?("Base") || name.end_with?("Base")
        end
      end
    end
  end
end
