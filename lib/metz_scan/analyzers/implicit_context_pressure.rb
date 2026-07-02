# frozen_string_literal: true

require_relative "implicit_context_pressure/ambient_context_collector"
require_relative "implicit_context_pressure/reference_set"
require_relative "implicit_context_pressure/triage"
require_relative "occurrence"
require_relative "package_map"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"

module MetzScan
  module Analyzers
    # Reports repeated ambient CurrentAttributes-style context access.
    class ImplicitContextPressure
      include ProjectAnalyzerTriage
      include Triage

      RULE_ID = "MetzProject/ImplicitContextPressure"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate ambient context signal; review whether dependencies should be explicit."
      WHY = "Ambient context hides dependencies from method signatures and makes workflows harder to reason about."
      SUGGESTED_NEXT_MOVES = [
        "Pass the context value explicitly into collaborators that use it.",
        "Keep request-scoped globals at application boundaries when possible."
      ].freeze
      MINIMUM_FILES = 3
      MINIMUM_PACKAGES = 2
      Finding = Struct.new(:source, :rule_id, :message, :ambient_context, :referring_files,
                           :referring_packages, :occurrences, :project_analyzer_status, :confidence,
                           :triage_severity, :triage_summary, :project_analyzer_metadata,
                           :why_it_matters, :suggested_next_moves, keyword_init: true) do
        def report_occurrences
          occurrence = occurrences.first
          [Occurrence.from(occurrence, context: occurrence&.context)].compact
        end
      end

      def initialize(paths: nil, index: nil, minimum_files: MINIMUM_FILES, minimum_packages: MINIMUM_PACKAGES)
        @paths = Array(paths)
        @index = index
        @minimum_files = minimum_files
        @minimum_packages = minimum_packages
      end

      def call
        ambient_references.group_by(&:ambient_context).filter_map do |ambient_context, references|
          finding_for(ambient_context, references)
        end
      end

      private

      attr_reader :paths, :index, :minimum_files, :minimum_packages

      def ambient_references
        ruby_files.flat_map { |path| AmbientContextCollector.new(path).call }
                  .reject { |reference| PackageMap.ignored_path?(reference.path) }
                  .select { |reference| PackageMap.package_for(reference.path) }
      end

      def ruby_files = RubyFileEnumerator.new(paths: paths, index: index).call

      def finding_for(ambient_context, references)
        grouped = ReferenceSet.new(references)
        return unless grouped.referring_files.size >= minimum_files
        return unless grouped.referring_packages.size >= minimum_packages

        Finding.new(finding_attributes(ambient_context, grouped))
      end

      def finding_attributes(ambient_context, grouped)
        category = implicit_context_category_for(ambient_context, grouped)

        finding_core_attributes(ambient_context, grouped, category)
          .merge(project_analyzer_triage_attributes)
          .merge(category_triage_attributes(category))
      end

      def finding_core_attributes(ambient_context, grouped, category)
        finding_identity_attributes(ambient_context, grouped)
          .merge(finding_reference_attributes(ambient_context, grouped, category))
      end

      def finding_identity_attributes(ambient_context, grouped)
        { source: source_name, rule_id: RULE_ID, message: message_for(ambient_context, grouped),
          ambient_context: ambient_context }
      end

      def finding_reference_attributes(ambient_context, grouped, category)
        { referring_files: grouped.referring_files, referring_packages: grouped.referring_packages,
          occurrences: grouped.references,
          project_analyzer_metadata: project_analyzer_metadata_for(ambient_context, grouped, category) }
      end

      def message_for(ambient_context, grouped)
        "#{ambient_context} is #{access_phrase(grouped)} from #{grouped.referring_files.size} files across " \
          "#{grouped.referring_packages.size} packages; consider passing context explicitly."
      end

      def project_analyzer_metadata_for(ambient_context, grouped, category)
        implicit_context_metadata(ambient_context, grouped, category).merge(grouped_metadata(grouped))
      end

      def implicit_context_metadata(ambient_context, grouped, category)
        { "project_analyzer_category" => category,
          "implicit_context_category" => category, "ambient_context" => ambient_context,
          "ambient_context_kind" => grouped.context_kind }
          .merge(context_specific_metadata(ambient_context, grouped))
      end

      def context_specific_metadata(ambient_context, grouped)
        return thread_current_metadata(grouped) if grouped.context_kind == "thread_current"

        { "current_receiver_scope" => current_receiver_scope_for(ambient_context),
          "current_attribute" => current_attribute_for(ambient_context) }
      end

      def thread_current_metadata(grouped)
        { "thread_current_key" => grouped.context_key }
      end

      def grouped_metadata(grouped)
        { "access_modes" => grouped.access_modes, "referring_files" => grouped.referring_files,
          "referring_packages" => grouped.referring_packages, "occurrences" => occurrences_metadata(grouped) }
      end

      def occurrences_metadata(grouped)
        grouped.references.map { |reference| reference_metadata(reference) }
      end

      def reference_metadata(reference)
        { "path" => reference.path, "line" => reference.line, "context" => reference.context,
          "expression" => reference.expression, "access_mode" => reference.access_mode }.compact
      end
    end
  end
end
