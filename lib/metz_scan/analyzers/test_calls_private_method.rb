# frozen_string_literal: true

require "rubocop"

require_relative "../project_index"
require_relative "project_analyzer_triage"
require_relative "ruby_file_enumerator"
require_relative "test_calls_private_method/call_site_collector"
require_relative "test_calls_private_method/finding"
require_relative "test_calls_private_method/metadata"
require_relative "test_calls_private_method/triage"

module MetzScan
  module Analyzers
    # Reports tests that call index-confirmed private or protected SUT methods.
    class TestCallsPrivateMethod
      include ProjectAnalyzerTriage
      include Metadata
      include Triage

      RULE_ID = "MetzProject/TestCallsPrivateMethod"
      PROJECT_ANALYZER_STATUS = "candidate"
      CONFIDENCE = "high"
      TRIAGE_SEVERITY = "manual review"
      TRIAGE_SUMMARY = "Candidate private-method testing signal; review whether the test should cover public behavior."
      WHY = "This is the index-confirmed form of Metz/TestReachesPrivate. Prefer this signal when both are " \
            "enabled because it confirms the test reaches a private or protected method on the subject under test."
      SUGGESTED_NEXT_MOVES = [
        "Exercise the public behavior that uses the private method instead of calling the method directly.",
        "Promote the method to the public interface only when callers outside the object genuinely need it.",
        "Keep Metz/TestReachesPrivate as the lower-confidence fallback for index-less runs."
      ].freeze
      TEST_FILE_PATTERNS = [
        "**/*_test.rb",
        "**/test_*.rb",
        "**/*_spec.rb"
      ].freeze
      PRIVATE_VISIBILITIES = %w[private protected].freeze
      SEND_METHODS = %i[send __send__].freeze
      EXAMPLE_GROUP_METHODS = %i[describe context feature example_group xdescribe xcontext
                                 fdescribe fcontext].freeze
      SHARED_EXAMPLE_GROUP_METHODS = %i[shared_examples shared_examples_for shared_context].freeze
      SUBJECT_DEFINERS = %i[subject subject!].freeze
      ASSIGNMENT_TYPES = %i[lvasgn ivasgn].freeze
      VARIABLE_TYPES = %i[lvar ivar].freeze
      SCOPE_KINDS = %i[class example_group].freeze
      private_constant :TEST_FILE_PATTERNS, :PRIVATE_VISIBILITIES, :SEND_METHODS, :EXAMPLE_GROUP_METHODS,
                       :SHARED_EXAMPLE_GROUP_METHODS, :SUBJECT_DEFINERS, :ASSIGNMENT_TYPES, :VARIABLE_TYPES,
                       :SCOPE_KINDS

      CallSite = Struct.new(:path, :line, :owner_name, :method_name, :method_identity, :receiver_kind,
                            keyword_init: true)
      Scope = Struct.new(:kind, :node, :sut_name, :subject_definitions, :assignments, keyword_init: true)

      def self.test_file?(path)
        normalized = path.to_s
        basename = File.basename(normalized)
        normalized.end_with?("_test.rb", "_spec.rb") || (basename.start_with?("test_") && basename.end_with?(".rb"))
      end

      def initialize(paths: nil, index: nil)
        @paths = Array(paths)
        @index = index || ProjectIndex.build(@paths)
      end

      def call
        return [] unless index.available?

        call_sites.filter_map { |site| finding_for(site) }
      end

      private

      attr_reader :paths, :index

      def call_sites
        test_files.flat_map { |path| CallSiteCollector.new(path, declarations: index.declarations).call }
      end

      def test_files
        RubyFileEnumerator.new(paths: paths, index: index).call.select { |path| self.class.test_file?(path) }
      end

      def finding_for(site)
        visibility = confirmed_visibility_for(site)
        return unless visibility

        Finding.new(finding_attributes(site, visibility))
      end

      def finding_attributes(site, visibility)
        core_finding_attributes(site, visibility)
          .merge(triage_attributes_for)
          .merge(project_analyzer_context_attributes(site, visibility))
      end

      def core_finding_attributes(site, visibility)
        { source: source_name, rule_id: RULE_ID, message: message_for(site, visibility),
          path: site.path, line: site.line, owner_name: site.owner_name, method_name: site.method_name,
          method_identity: site.method_identity, receiver_kind: site.receiver_kind, visibility: visibility,
          occurrences: [site] }
      end

      def confirmed_visibility_for(site)
        declarations = confirming_declarations_for(site)
        return if declarations.empty?

        visibilities = declarations.map(&:visibility).uniq
        return unless visibilities.all? { |visibility| PRIVATE_VISIBILITIES.include?(visibility) }

        visibilities.one? ? visibilities.first : visibilities.join("/")
      end

      def confirming_declarations_for(site)
        methods_by_owner.fetch(site.owner_name, []).select do |declaration|
          declaration.method_identity == site.method_identity && !self.class.test_file?(declaration.path.to_s)
        end
      end

      def methods_by_owner
        @methods_by_owner ||= index.method_declarations.group_by(&:owner_name)
      end
    end
  end
end
