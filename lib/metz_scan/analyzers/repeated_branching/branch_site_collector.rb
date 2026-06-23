# frozen_string_literal: true

require "rubocop"

require_relative "branch_value"
require_relative "contextual_node_walker"
require_relative "predicate_chain"

module MetzScan
  module Analyzers
    class RepeatedBranching
      class BranchSiteCollector
        BranchSite = Struct.new(:signature, :kind, :decision, :branch_values, :enclosing_name, :method_name,
                                :path, :line, :expression, keyword_init: true)
        SiteDraft = Struct.new(:kind, :decision, :branch_conditions, :branch_values, :contextual_node,
                               keyword_init: true)

        def initialize(path)
          @path = path
        end

        def call
          return [] unless File.file?(path)

          contextual_nodes.filter_map { |contextual_node| branch_site_for(contextual_node) }
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

        def case_branch?(node)
          node.type == :case && node.children.first
        end

        def root_if_branch?(node)
          node.type == :if && node.loc.respond_to?(:keyword) && node.loc.keyword.source == "if"
        end

        def branch_site_for(contextual_node)
          node = contextual_node.node
          return case_site(contextual_node) if case_branch?(node)
          return if_site(contextual_node) if root_if_branch?(node)

          nil
        end

        def case_site(contextual_node)
          node = contextual_node.node
          decision = node.children.first.source
          values = case_values(node)
          build_site(:case, decision, values, contextual_node)
        end

        def case_values(node)
          values = node.children.grep(RuboCop::AST::WhenNode).flat_map { |when_node| when_values(when_node) }
          values.uniq(&:signature).sort_by { |value| [value.text, value.signature] }
        end

        def when_values(when_node)
          when_node.conditions.map { |condition| condition_value(condition) }
        end

        def condition_value(condition)
          BranchValue.for(condition)
        end

        def if_site(contextual_node)
          predicate_chain = PredicateChain.new(contextual_node.node).call
          return unless predicate_chain

          build_site(:if, predicate_chain.decision, predicate_chain.branch_values, contextual_node)
        end

        def build_site(kind, decision, values, contextual_node)
          draft = site_draft(kind, decision, values, contextual_node)
          return if draft.branch_values.empty?

          BranchSite.new(site_attributes(draft))
        end

        def site_draft(kind, decision, values, contextual_node)
          SiteDraft.new(kind: kind, decision: decision, branch_conditions: values,
                        branch_values: branch_values_for(values), contextual_node: contextual_node)
        end

        def site_attributes(draft)
          context_attributes(draft.contextual_node).merge(site_signature_attributes(draft))
                                                   .merge(site_location_attributes(draft))
        end

        def signature_for_draft(draft)
          signature_for(draft.kind, draft.decision, signatures_for(draft.branch_conditions))
        end

        def site_signature_attributes(draft)
          { signature: signature_for_draft(draft), kind: draft.kind,
            decision: draft.decision, branch_values: draft.branch_values }
        end

        def site_location_attributes(draft)
          node = draft.contextual_node.node
          { path: path, line: node.loc.expression.line, expression: first_line(node) }
        end

        def context_attributes(contextual_node)
          { enclosing_name: contextual_node.enclosing_name, method_name: contextual_node.method_name }
        end

        def branch_values_for(values)
          values.map { |value| value.respond_to?(:text) ? value.text : value }
        end

        def signatures_for(values)
          values.map { |value| value.respond_to?(:signature) ? value.signature : value }
        end

        def signature_for(kind, decision, values)
          [kind, decision, values].join(":")
        end

        def first_line(node)
          node.loc.expression.source.lines.first.strip
        end
      end
    end
  end
end
