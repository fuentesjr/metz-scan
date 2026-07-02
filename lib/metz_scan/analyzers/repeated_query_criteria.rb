# frozen_string_literal: true

require "rubocop"

require_relative "contextual_node_walker"
require_relative "occurrence"
require_relative "package_map"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"

module MetzScan
  module Analyzers
    # Reports repeated hash-style ActiveRecord query predicates across packages.
    class RepeatedQueryCriteria
      include ProjectAnalyzerTriage

      RULE_ID = "MetzProject/RepeatedQueryCriteria"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "medium"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate repeated query signal; review whether criteria belong behind a named query."
      WHY = "Repeated query predicates spread data-access rules across callers and make policy changes harder to find."
      SUGGESTED_NEXT_MOVES = [
        "Extract a named scope or query object when the predicate represents a reusable business concept.",
        "Keep one-off lookup criteria inline when repetition is incidental or purely local."
      ].freeze
      MINIMUM_FILES = 3
      MINIMUM_PACKAGES = 2
      MINIMUM_CRITERIA_KEYS = 2
      Finding = Struct.new(:source, :rule_id, :message, :query, :receiver, :criteria_keys,
                           :referring_files, :referring_packages, :occurrences,
                           :project_analyzer_status, :confidence, :triage_severity, :triage_summary,
                           :project_analyzer_metadata, :why_it_matters, :suggested_next_moves,
                           keyword_init: true) do
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
        query_sites.group_by(&:fingerprint).filter_map do |_fingerprint, sites|
          finding_for(sites)
        end
      end

      private

      attr_reader :paths, :index, :minimum_files, :minimum_packages

      def query_sites
        ruby_files.flat_map { |path| QuerySiteCollector.new(path).call }
                  .reject { |site| PackageMap.ignored_path?(site.path) }
                  .select { |site| PackageMap.package_for(site.path) }
      end

      def ruby_files
        RubyFileEnumerator.new(paths: paths, index: index).call
      end

      def finding_for(sites)
        grouped = QuerySiteSet.new(sites)
        return unless grouped.referring_files.size >= minimum_files
        return unless grouped.referring_packages.size >= minimum_packages

        first = grouped.sites.first
        Finding.new(finding_attributes(first, grouped))
      end

      def finding_attributes(first, grouped)
        core_finding_attributes(first, grouped)
          .merge(project_analyzer_triage_attributes)
          .merge(project_analyzer_context_attributes(first, grouped))
      end

      def core_finding_attributes(first, grouped)
        { source: source_name, rule_id: RULE_ID, message: message_for(first, grouped),
          query: first.query, receiver: first.receiver, criteria_keys: first.criteria_keys,
          referring_files: grouped.referring_files, referring_packages: grouped.referring_packages,
          occurrences: grouped.sites }
      end

      def project_analyzer_context_attributes(first, grouped)
        { project_analyzer_metadata: project_analyzer_metadata_for(first, grouped),
          why_it_matters: WHY, suggested_next_moves: SUGGESTED_NEXT_MOVES }
      end

      def message_for(site, grouped)
        "#{site.query} appears in #{grouped.referring_files.size} files across " \
          "#{grouped.referring_packages.size} packages; consider naming the query criteria."
      end

      def project_analyzer_metadata_for(site, grouped)
        { "project_analyzer_category" => "where_hash_criteria",
          "repeated_query_category" => "where_hash_criteria", "query" => site.query,
          "receiver" => site.receiver, "criteria_keys" => site.criteria_keys,
          "referring_files" => grouped.referring_files, "referring_packages" => grouped.referring_packages,
          "occurrences" => occurrences_metadata(grouped) }
      end

      def occurrences_metadata(grouped)
        grouped.sites.map { |site| occurrence_metadata(site) }
      end

      def occurrence_metadata(site)
        { "path" => site.path, "line" => site.line, "context" => site.context,
          "expression" => site.expression }.compact
      end

      class QuerySiteSet
        def initialize(sites)
          @sites = sites.sort_by { |site| [site.path, site.line.to_i] }
        end

        attr_reader :sites

        def referring_files
          sites.map(&:path).uniq
        end

        def referring_packages
          sites.map { |site| PackageMap.package_for(site.path) }.compact.uniq.sort
        end
      end

      class QuerySiteCollector
        QuerySite = Struct.new(:receiver, :criteria_keys, :enclosing_name, :method_name, :path, :line,
                               :expression, keyword_init: true) do
          def query
            "#{receiver}.where(#{criteria_keys.join(', ')})"
          end

          def fingerprint
            [receiver, criteria_keys].join(":")
          end

          def context
            return "#{enclosing_name}#{method_name}" if enclosing_name && method_name

            method_name || enclosing_name
          end
        end

        def initialize(path)
          @path = path
        end

        def call
          contextual_nodes.filter_map { |contextual_node| query_site_for(contextual_node) }
        rescue Parser::SyntaxError
          []
        end

        private

        attr_reader :path

        def processed_source
          RuboCop::ProcessedSource.new(File.read(path), RUBY_VERSION.to_f)
        end

        def contextual_nodes
          ContextualNodeWalker.new(processed_source.ast).nodes
        end

        def repeated_query_site?(node)
          node.type == :send &&
            node.method_name == :where &&
            constant_receiver?(node.receiver) &&
            criteria_keys_for(node).size >= MINIMUM_CRITERIA_KEYS
        end

        def constant_receiver?(node)
          node&.type == :const
        end

        def query_site_for(contextual_node)
          node = contextual_node.node
          return unless repeated_query_site?(node)

          QuerySite.new(receiver: node.receiver.source, criteria_keys: criteria_keys_for(node),
                        enclosing_name: contextual_node.enclosing_name, method_name: contextual_node.method_name,
                        path: path, line: node.loc.expression.line, expression: first_line(node))
        end

        def criteria_keys_for(node)
          hash = node.arguments.first
          return [] unless hash&.type == :hash
          return [] unless hash.children.all? { |child| child.type == :pair }

          hash.children.filter_map { |pair| literal_key(pair.children.first) }.sort
        end

        def literal_key(node)
          node.value.to_s if %i[sym str].include?(node.type)
        end

        def first_line(node)
          node.loc.expression.source.lines.first.strip
        end
      end
    end
  end
end
