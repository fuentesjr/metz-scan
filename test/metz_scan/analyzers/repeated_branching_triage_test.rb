# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/repeated_branching"

module MetzScan
  module Analyzers
    class RepeatedBranchingTriageTest < Minitest::Test
      def test_repeated_branching_is_validated_design_pressure
        with_branching_files do |files|
          finding = RepeatedBranching.new(index: fake_index(files)).call.first

          assert_validated_design_pressure(finding)
          assert_equal "state", finding.project_analyzer_metadata.fetch("decision_subject_kind")
        end
      end

      def test_generic_subjects_are_context_required
        with_branching_files(source: generic_branching_source) do |files|
          finding = RepeatedBranching.new(index: fake_index(files)).call.first

          assert_context_required(finding)
        end
      end

      def test_expression_subjects_are_validated_design_pressure
        with_branching_files(source: expression_branching_source) do |files|
          finding = RepeatedBranching.new(index: fake_index(files)).call.first

          assert_validated_design_pressure(finding)
          assert_equal "expression", finding.project_analyzer_metadata.fetch("decision_subject_kind")
        end
      end

      private

      def assert_validated_design_pressure(finding)
        assert_equal "validated", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "design pressure", finding.triage_severity
      end

      def assert_context_required(finding)
        assert_equal "validated", finding.project_analyzer_status
        assert_equal "low", finding.confidence
        assert_equal "context required", finding.triage_severity
        assert_match(/reported contexts and branch values/i, finding.triage_summary)
      end

      def with_branching_files(source: branching_source)
        Dir.mktmpdir do |dir|
          yield [write_file(dir, "orders.rb", source), write_file(dir, "invoices.rb", source)]
        end
      end

      def write_file(dir, name, source)
        File.join(dir, name).tap { |path| File.write(path, source) }
      end

      def branching_source
        "case order.status\nwhen \"pending\"\n  nil\nwhen \"paid\", \"cancelled\"\n  nil\nend\n"
      end

      def generic_branching_source
        "case action\nwhen \"block\"\n  nil\nwhen \"silence\"\n  nil\nend\n"
      end

      def expression_branching_source
        "case File.extname(URI(url).path || \"\")\nwhen \".png\"\n  nil\nwhen \".jpg\"\n  nil\nend\n"
      end

      def fake_index(files)
        Struct.new(:indexed_files, keyword_init: true) do
          def backend_name = :fake
          def available? = true
        end.new(indexed_files: files)
      end
    end
  end
end
