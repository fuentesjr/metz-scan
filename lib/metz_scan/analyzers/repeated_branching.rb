# frozen_string_literal: true

require_relative "../project_index"
require_relative "occurrence"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"
require_relative "repeated_branching/branch_site_collector"
require_relative "repeated_branching/decision_subject"
require_relative "repeated_branching/triage"

module MetzScan
  module Analyzers
    # Groups repeated case/if branching decisions across indexed Ruby files.
    class RepeatedBranching
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/RepeatedBranching"
      PROJECT_ANALYZER_STATUS = "validated"
      DEFAULT_OUTPUT_ELIGIBLE = true
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "design pressure"
      TRIAGE_SUMMARY = "Validated repeated-decision signal; review repeated decisions in context."
      WHY = "Repeated branching spreads one domain decision across files and makes change ripple outward."
      SUGGESTED_NEXT_MOVES = [
        "Name the domain decision once and reuse it instead of repeating the same branch table.",
        "Consider polymorphism, a strategy object, or a small lookup object when the branch represents type behavior."
      ].freeze
      Finding = Struct.new(:source, :rule_id, :message, :decision, :kind, :branch_values, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true) do
        def report_occurrences
          occurrences.map { |occurrence| Occurrence.from(occurrence, context: context_name(occurrence)) }
        end

        def context_name(occurrence)
          [occurrence.enclosing_name, occurrence.method_name].compact.join.then { |name| name unless name.empty? }
        end
      end

      def initialize(paths: nil, index: nil, minimum_occurrences: 2)
        @paths = Array(paths)
        @index = index
        @minimum_occurrences = minimum_occurrences
      end

      def call
        grouped_sites.filter_map { |_signature, sites| finding_for(sites) }
      end

      private

      attr_reader :paths, :index, :minimum_occurrences

      def grouped_sites
        branch_sites.group_by(&:signature)
      end

      def branch_sites
        ruby_files.flat_map { |path| BranchSiteCollector.new(path).call }
      end

      def ruby_files
        RubyFileEnumerator.new(paths: paths, index: index).call
      end

      def finding_for(sites)
        return if distinct_paths(sites).size < minimum_occurrences

        first = sites.first
        Finding.new(finding_attributes(first, sites))
      end

      def finding_attributes(first, sites)
        subject = DecisionSubject.for(first.decision)
        core_finding_attributes(first, sites, subject).merge(triage_attributes_for(first, sites, subject))
      end

      def triage_attributes_for(first, sites, subject)
        subject_triage_attributes(subject).merge(
          project_analyzer_metadata: project_analyzer_metadata_for(first, sites, subject),
          why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES
        )
      end

      def subject_triage_attributes(subject)
        Triage.attributes_for(subject, status: PROJECT_ANALYZER_STATUS, fallback: project_analyzer_triage_attributes)
      end

      def core_finding_attributes(first, sites, subject)
        { source: source_name, rule_id: RULE_ID, message: message_for(first, sites, subject),
          decision: first.decision, kind: first.kind, branch_values: first.branch_values, occurrences: sites }
      end

      def distinct_paths(sites)
        sites.map(&:path).uniq
      end

      def message_for(site, sites, subject)
        "#{site.decision} (#{subject.label}) branches in #{distinct_paths(sites).size} files" \
          "#{context_suffix(sites)}; " \
          "consider consolidating the decision."
      end

      def context_suffix(sites)
        names = context_names(sites)
        return "" if names.empty?

        ": #{names.join(', ')}"
      end

      def context_names(sites)
        sites.filter_map { |site| context_name(site) }.uniq.sort
      end

      def context_name(site)
        [site.enclosing_name, site.method_name].compact.join.then { |name| name unless name.empty? }
      end

      def project_analyzer_metadata_for(site, sites, subject)
        { "decision" => site.decision, "kind" => site.kind.to_s,
          "branch_values" => site.branch_values, "decision_subject_kind" => subject.kind,
          "decision_subject_label" => subject.label, "decision_subject_summary" => subject.summary,
          "occurrences" => sites.map { |occurrence| occurrence_metadata(occurrence) } }
      end

      def occurrence_metadata(site)
        { "context" => context_name(site), "enclosing" => site.enclosing_name,
          "method" => site.method_name, "path" => site.path, "line" => site.line,
          "expression" => site.expression }.compact
      end
    end
  end
end
