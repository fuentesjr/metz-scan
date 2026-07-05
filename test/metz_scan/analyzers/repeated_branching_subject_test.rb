# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/repeated_branching"

module MetzScan
  module Analyzers
    class RepeatedBranchingSubjectTest < Minitest::Test
      def test_labels_generic_branch_subjects
        with_branching_files(generic_subject_branching_files) do |files|
          finding = analyze(files).first

          assert_equal "generic", finding.project_analyzer_metadata.fetch("decision_subject_kind")
          assert_includes finding.message, "action (generic branch subject) branches"
        end
      end

      def test_labels_state_branch_subjects
        with_branching_files(state_subject_branching_files) do |files|
          assert_state_branch_subject(analyze(files).first)
        end
      end

      def test_labels_expression_branch_subjects
        with_branching_files(expression_subject_branching_files) do |files|
          finding = analyze(files).first

          assert_equal "expression", finding.project_analyzer_metadata.fetch("decision_subject_kind")
          assert_includes finding.message, "File.extname(URI(url).path || \"\") (expression subject) branches"
        end
      end

      private

      def assert_state_branch_subject(finding)
        assert_equal "state", finding.project_analyzer_metadata.fetch("decision_subject_kind")
        assert_equal "state branch subject", finding.project_analyzer_metadata.fetch("decision_subject_label")
        assert_includes finding.project_analyzer_metadata.fetch("decision_subject_summary"), "State-like subject"
        assert_includes finding.message, "order.status (state branch subject) branches"
      end

      def analyze(files)
        RepeatedBranching.new(index: SubjectFakeBranchIndex.new(available: true, indexed_files: files)).call
      end

      def generic_subject_branching_files
        [generic_subject_branching_source("EmailDomainBlockBatch"), generic_subject_branching_source("IpBlockBatch")]
      end

      def generic_subject_branching_source(class_name)
        <<~RUBY
          class #{class_name}
            def save
              case action
              when "block" then nil
              when "silence" then nil
              end
            end
          end
        RUBY
      end

      def state_subject_branching_files
        [state_subject_branching_source("OrderExporter"), state_subject_branching_source("OrderNotifier")]
      end

      def state_subject_branching_source(class_name)
        <<~RUBY
          class #{class_name}
            def call(order)
              case order.status
              when "pending" then nil
              when "paid" then nil
              end
            end
          end
        RUBY
      end

      def expression_subject_branching_files
        [expression_subject_branching_source("SearchIndexer"), expression_subject_branching_source("SearchBlurb")]
      end

      def expression_subject_branching_source(class_name)
        <<~RUBY
          class #{class_name}
            def clean(url)
              case File.extname(URI(url).path || "")
              when ".png" then nil
              when ".jpg" then nil
              end
            end
          end
        RUBY
      end

      def with_branching_files(contents)
        Dir.mktmpdir { |dir| yield write_branching_files(dir, contents) }
      end

      def write_branching_files(dir, contents)
        contents.map.with_index do |source, index|
          File.join(dir, "branching_#{index}.rb").tap { |path| File.write(path, source) }
        end
      end
    end

    class SubjectFakeBranchIndex
      def initialize(available:, indexed_files:)
        @available = available
        @indexed_files = indexed_files
      end

      attr_reader :indexed_files

      def backend_name = :fake

      def available? = @available
    end
  end
end
