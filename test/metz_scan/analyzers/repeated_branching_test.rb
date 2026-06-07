# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/repeated_branching"

module MetzScan
  module Analyzers
    module BranchingFixtureSources
      def case_branching_files
        [case_branching_source("order"), case_branching_source("order")]
      end

      def unrelated_receiver_files
        [case_branching_source("order"), case_branching_source("invoice")]
      end

      def predicate_branching_files
        [predicate_branching_source, predicate_branching_source]
      end

      def mixed_predicate_branching_files
        [mixed_predicate_branching_source, mixed_predicate_branching_source]
      end

      def case_branching_source(receiver)
        "case #{receiver}.status\nwhen \"pending\"\n  nil\nwhen \"paid\", \"cancelled\"\n  nil\nend\n"
      end

      def predicate_branching_source
        "if user.admin?\n  nil\nelsif user.manager?\n  nil\nend\n"
      end

      def mixed_predicate_branching_source
        "if user.admin?\n  nil\nelsif expensive_check\n  nil\nelsif user.staff?\n  nil\nend\n"
      end

      def ternary_source
        "value = user.admin? ? \"admin\" : \"member\"\n"
      end

      def repeated_in_one_file_source
        "#{case_branching_source('order')}\n#{case_branching_source('order')}"
      end

      def string_status_source
        "case order.status\nwhen \"paid\"\n  nil\nend\n"
      end

      def symbol_status_source
        "case order.status\nwhen :paid\n  nil\nend\n"
      end
    end

    class RepeatedBranchingTest < Minitest::Test
      include BranchingFixtureSources

      def test_reports_case_branching_repeated_across_files
        with_branching_files(case_branching_files) do |files|
          finding = analyze(files).first

          assert_case_finding(finding)
          refute_empty finding.suggested_next_moves
        end
      end

      def test_does_not_group_same_values_on_unrelated_receivers
        with_branching_files(unrelated_receiver_files) do |files|
          assert_empty analyze(files)
        end
      end

      def test_reports_if_predicate_chain_repeated_across_files
        with_branching_files(predicate_branching_files) do |files|
          finding = analyze(files).first

          assert_equal "user", finding.decision
          assert_equal %w[admin? manager?], finding.branch_values
        end
      end

      def test_does_not_drop_unsupported_conditions_from_predicate_chain
        with_branching_files(mixed_predicate_branching_files) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_ternary_if_nodes
        with_branching_files([ternary_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_repeated_branching_must_appear_across_distinct_files
        with_branching_files([repeated_in_one_file_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_case_branch_literals_are_type_aware
        with_branching_files([string_status_source, symbol_status_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_uses_explicit_paths_when_index_is_unavailable
        with_branching_files(case_branching_files) do |files|
          finding = RepeatedBranching.new(paths: files, index: fake_index([], available: false)).call.first

          assert_equal "order.status", finding.decision
        end
      end

      private

      def analyze(files)
        RepeatedBranching.new(index: fake_index(files)).call
      end

      def assert_case_finding(finding)
        assert_equal "MetzProject/RepeatedBranching", finding.rule_id
        assert_equal "order.status", finding.decision
        assert_equal %w[cancelled paid pending], finding.branch_values
        assert_equal 2, finding.occurrences.size
        assert_includes finding.message, "order.status branches in 2 files"
      end

      def with_branching_files(contents)
        Dir.mktmpdir { |dir| yield write_branching_files(dir, contents) }
      end

      def write_branching_files(dir, contents)
        contents.map.with_index { |source, index| write_branching_file(dir, index, source) }
      end

      def write_branching_file(dir, index, source)
        File.join(dir, "branching_#{index}.rb").tap { |path| File.write(path, source) }
      end

      def fake_index(files, available: true)
        FakeBranchIndex.new(available: available, indexed_files: files)
      end
    end

    class RepeatedBranchingRubydexTest < Minitest::Test
      include BranchingFixtureSources

      def test_reports_repeated_case_branching_from_project_index
        skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

        with_rubydex_fixture do |index|
          finding = RepeatedBranching.new(index: index).call.first

          assert_equal "order.status", finding.decision
        end
      end

      private

      def with_rubydex_fixture
        Dir.mktmpdir do |dir|
          case_branching_files.each_with_index { |source, index| write_file(dir, index, source) }
          yield ProjectIndex.build([dir], backend: :rubydex)
        end
      end

      def write_file(dir, index, source)
        File.write(File.join(dir, "branching_#{index}.rb"), source)
      end
    end

    class FakeBranchIndex
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
