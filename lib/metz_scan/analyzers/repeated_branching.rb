# frozen_string_literal: true

require_relative "../project_index"
require_relative "repeated_branching/branch_site_collector"

module MetzScan
  module Analyzers
    # Groups repeated case/if branching decisions across indexed Ruby files.
    class RepeatedBranching
      RULE_ID = "MetzProject/RepeatedBranching"
      PROJECT_ANALYZER_STATUS = "experimental"
      CONFIDENCE = "early"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Useful signal, not proof; review repeated decisions in context."
      WHY = "Repeated branching spreads one domain decision across files and makes change ripple outward."
      SUGGESTED_NEXT_MOVES = [
        "Name the domain decision once and reuse it instead of repeating the same branch table.",
        "Consider polymorphism, a strategy object, or a small lookup object when the branch represents type behavior."
      ].freeze
      RUBY_GLOB = "**/*.rb"

      Finding = Struct.new(:source, :rule_id, :message, :decision, :kind, :branch_values, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true)

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

      def finding_for(sites)
        return if distinct_paths(sites).size < minimum_occurrences

        first = sites.first
        Finding.new(finding_attributes(first, sites))
      end

      def finding_attributes(first, sites)
        { source: source_name, rule_id: RULE_ID, message: message_for(first, sites),
          decision: first.decision, kind: first.kind, branch_values: first.branch_values,
          occurrences: sites }.merge(project_analyzer_triage_attributes,
                                     project_analyzer_metadata: project_analyzer_metadata_for(first, sites),
                                     why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES)
      end

      def project_analyzer_triage_attributes
        { project_analyzer_status: PROJECT_ANALYZER_STATUS, confidence: CONFIDENCE,
          triage_severity: TRIAGE_SEVERITY, triage_summary: TRIAGE_SUMMARY }
      end

      def source_name
        index ? index.backend_name.to_s : "paths"
      end

      def distinct_paths(sites)
        sites.map(&:path).uniq
      end

      def message_for(site, sites)
        "#{site.decision} branches in #{distinct_paths(sites).size} files#{context_suffix(sites)}; " \
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

      def project_analyzer_metadata_for(site, sites)
        { "decision" => site.decision, "kind" => site.kind.to_s,
          "branch_values" => site.branch_values,
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
