# frozen_string_literal: true

require "rubocop"

require_relative "contextual_node_walker"
require_relative "occurrence"
require_relative "package_map"
require_relative "project_analyzer_triage"
require_relative "repeated_query_criteria/triage"
require_relative "ruby_file_enumerator"

module MetzScan
  module Analyzers
    # Reports repeated hash-style ActiveRecord query predicates across packages.
    class RepeatedQueryCriteria
      include ProjectAnalyzerTriage
      include Triage

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
        category = repeated_query_category_for(first)

        core_finding_attributes(first, grouped, category)
          .merge(project_analyzer_triage_attributes, category_triage_attributes(category))
          .merge(project_analyzer_context_attributes(first, grouped, category))
      end

      def core_finding_attributes(first, grouped, category)
        { source: source_name, rule_id: RULE_ID, message: message_for(first, grouped, category),
          query: first.query, receiver: first.receiver, criteria_keys: first.criteria_keys,
          referring_files: grouped.referring_files, referring_packages: grouped.referring_packages,
          occurrences: grouped.sites }
      end

      def project_analyzer_context_attributes(first, grouped, category)
        { project_analyzer_metadata: project_analyzer_metadata_for(first, grouped, category) }
      end

      def message_for(site, grouped, category)
        "#{site.query} #{query_message_phrase(site, category)} in #{grouped.referring_files.size} files across " \
          "#{grouped.referring_packages.size} packages; consider naming the query criteria."
      end

      def project_analyzer_metadata_for(site, grouped, category)
        query_metadata(site, category).merge(query_reference_metadata(grouped))
      end

      def query_metadata(site, category)
        query_identity_metadata(site, category).merge(query_shape_metadata(site))
      end

      def query_identity_metadata(site, category)
        { "project_analyzer_category" => category, "repeated_query_category" => category, "query" => site.query,
          "query_method" => site.query_method, "query_operation" => site.query_operation }
      end

      def query_shape_metadata(site)
        { "receiver" => site.receiver, "criteria_keys" => site.criteria_keys,
          "receiver_shape" => site.receiver_shape, "criteria_key_shape" => criteria_key_shape_for(site) }
      end

      def query_reference_metadata(grouped)
        { "referring_files" => grouped.referring_files, "referring_packages" => grouped.referring_packages,
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
        FINDER_QUERY_METHODS = %i[find_by find_or_create_by find_or_initialize_by].freeze
        QuerySite = Struct.new(:receiver, :criteria_keys, :query_method, :query_operation, :enclosing_name,
                               :method_name, :path, :line, :expression, keyword_init: true) do
          def query
            "#{receiver}.#{query_method}(#{criteria_keys.join(', ')})"
          end

          def receiver_shape
            receiver.include?(".") ? "scope_chain" : "constant"
          end

          def fingerprint
            [receiver, query_method, criteria_keys].join(":")
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

        def receiver_fingerprint_for(node)
          return unless node
          return node.source if node.type == :const
          return unless simple_scope_call?(node)

          parent = receiver_fingerprint_for(node.receiver)
          "#{parent}.#{node.method_name}" if parent
        end

        def simple_scope_call?(node)
          node.type == :send && node.receiver && node.arguments.empty? &&
            node.method_name.to_s.match?(/\A[a-z_]\w*[!?]?\z/)
        end

        def query_site_for(contextual_node)
          node = contextual_node.node
          query_attributes = query_attributes_for(node)
          return unless query_attributes

          QuerySite.new(query_attributes.merge(context_attributes_for(contextual_node, node)))
        end

        def context_attributes_for(contextual_node, node)
          { enclosing_name: contextual_node.enclosing_name, method_name: contextual_node.method_name,
            path: path, line: node.loc.expression.line, expression: first_line(node) }
        end

        def query_attributes_for(node)
          return unless node.type == :send

          positive_where_query_attributes(node) ||
            finder_query_attributes(node) ||
            negative_where_query_attributes(node)
        end

        def positive_where_query_attributes(node)
          return unless node.method_name == :where

          query_attributes_for_parts(node.receiver, criteria_keys_for(node), "where", "filter")
        end

        def finder_query_attributes(node)
          return unless FINDER_QUERY_METHODS.include?(node.method_name)

          query_attributes_for_parts(node.receiver, criteria_keys_for(node), node.method_name.to_s, "finder")
        end

        def negative_where_query_attributes(node)
          return unless node.method_name == :not

          receiver_node = empty_where_receiver_for(node)
          return unless receiver_node

          query_attributes_for_parts(receiver_node.receiver, criteria_keys_for(node), "where.not", "negative_filter")
        end

        def empty_where_receiver_for(node)
          receiver_node = node.receiver
          receiver_node if receiver_node&.type == :send && receiver_node.method_name == :where &&
                           receiver_node.arguments.empty?
        end

        def query_attributes_for_parts(receiver_node, criteria_keys, query_method, query_operation)
          receiver = receiver_fingerprint_for(receiver_node)
          return unless receiver
          return unless criteria_keys.size >= MINIMUM_CRITERIA_KEYS

          { receiver: receiver, criteria_keys: criteria_keys, query_method: query_method,
            query_operation: query_operation }
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
