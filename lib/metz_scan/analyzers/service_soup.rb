# frozen_string_literal: true

require_relative "../project_index"
require_relative "occurrence"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"
require_relative "service_soup/setup_workflow_triage"
require_relative "service_soup/workflow_collector"

module MetzScan
  module Analyzers
    # Reports workflow methods that coordinate many service-style calls.
    class ServiceSoup
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/ServiceSoup"
      PROJECT_ANALYZER_STATUS = "validated"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "design pressure"
      TRIAGE_SUMMARY = "Validated workflow signal; review methods that coordinate several distinct services."
      WHY = "Service-object soup scatters one workflow across many procedural steps " \
            "and makes orchestration harder to change."
      SUGGESTED_NEXT_MOVES = [
        "Introduce a workflow object that owns the multi-step process.",
        "Keep the controller or job action at one high-level command when possible."
      ].freeze
      Finding = Struct.new(:source, :rule_id, :message, :workflow, :services, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true) do
        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: workflow) }
        end
      end

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
        RubyFileEnumerator.new(paths: paths, index: index).call
      end

      def finding_for(workflow)
        services = service_names(workflow)
        return if services.size < minimum_services

        Finding.new(finding_attributes(workflow, services))
      end

      def finding_attributes(workflow, services)
        workflow_attributes(workflow, services).merge(
          triage_attributes_for(workflow),
          project_analyzer_metadata: project_analyzer_metadata_for(workflow),
          why_it_matters: why_for(workflow), suggested_next_moves: suggested_next_moves_for(workflow)
        )
      end

      def triage_attributes_for(workflow)
        return setup_triage_attributes if setup_orchestration?(workflow)

        project_analyzer_triage_attributes
      end

      def setup_triage_attributes
        SetupWorkflowTriage.attributes(PROJECT_ANALYZER_STATUS)
      end

      def why_for(workflow)
        setup_orchestration?(workflow) ? SetupWorkflowTriage::WHY : WHY
      end

      def suggested_next_moves_for(workflow)
        setup_orchestration?(workflow) ? SetupWorkflowTriage::SUGGESTED_NEXT_MOVES : SUGGESTED_NEXT_MOVES
      end

      def workflow_attributes(workflow, services)
        { source: source_name, rule_id: RULE_ID, message: message_for(workflow, services),
          workflow: workflow.name, services: services, occurrences: workflow.service_calls }
      end

      def service_names(workflow)
        workflow.service_calls.map(&:service_name).uniq.sort
      end

      def setup_orchestration?(workflow)
        SetupWorkflowTriage.setup?(workflow)
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
