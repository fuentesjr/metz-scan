# frozen_string_literal: true

require_relative "../project_index"
require_relative "service_soup/workflow_collector"

module MetzScan
  module Analyzers
    # Reports workflow methods that coordinate many service-style calls.
    class ServiceSoup
      RULE_ID = "MetzProject/ServiceSoup"
      WHY = "Service-object soup scatters one workflow across many procedural steps " \
            "and makes orchestration harder to change."
      SUGGESTED_NEXT_MOVES = [
        "Introduce a workflow object that owns the multi-step process.",
        "Keep the controller or job action at one high-level command when possible."
      ].freeze
      RUBY_GLOB = "**/*.rb"

      Finding = Struct.new(:source, :rule_id, :message, :workflow, :services, :occurrences,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true)

      def initialize(paths: nil, index: nil, minimum_services: 3)
        @paths = Array(paths)
        @index = index
        @minimum_services = minimum_services
      end

      def call
        workflows.filter_map { |workflow| finding_for(workflow) }
      end

      private

      attr_reader :paths, :index, :minimum_services

      def workflows
        ruby_files.flat_map { |path| WorkflowCollector.new(path).call }
      end

      def ruby_files
        return ruby_files_for(paths) unless paths.empty?
        return index.indexed_files if index&.available?

        []
      end

      def ruby_files_for(paths)
        paths.flat_map { |path| ruby_files_under(path) }.uniq.sort
      end

      def ruby_files_under(path)
        expanded = File.expand_path(path)
        return Dir.glob(File.join(expanded, RUBY_GLOB)) if File.directory?(expanded)
        return [expanded] if File.file?(expanded) && File.extname(expanded) == ".rb"

        []
      end

      def finding_for(workflow)
        services = service_names(workflow)
        return if services.size < minimum_services

        Finding.new(finding_attributes(workflow, services))
      end

      def finding_attributes(workflow, services)
        { source: source_name, rule_id: RULE_ID, message: message_for(workflow, services),
          workflow: workflow.name, services: services, occurrences: workflow.service_calls,
          project_analyzer_metadata: project_analyzer_metadata_for(workflow),
          why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }
      end

      def source_name
        index ? index.backend_name.to_s : "paths"
      end

      def service_names(workflow)
        workflow.service_calls.map(&:service_name).uniq.sort
      end

      def message_for(workflow, services)
        "#{workflow.name} coordinates #{services.size} distinct services; " \
          "consider a workflow object that owns the process."
      end

      def project_analyzer_metadata_for(workflow)
        { "workflow" => workflow_metadata(workflow),
          "services" => workflow.service_calls.map { |service_call| service_call_metadata(service_call) } }
      end

      def workflow_metadata(workflow)
        { "context" => workflow.name, "enclosing" => workflow.enclosing_name,
          "method" => workflow.method_name, "line" => workflow.line,
          "expression" => workflow.expression }.compact
      end

      def service_call_metadata(service_call)
        { "service" => service_call.service_name, "path" => service_call.path,
          "line" => service_call.line, "expression" => service_call.expression,
          "style" => service_call.style.to_s }.compact
      end
    end
  end
end
