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
        end
      end

      private

      def assert_validated_design_pressure(finding)
        assert_equal "validated", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "design pressure", finding.triage_severity
      end

      def with_branching_files
        Dir.mktmpdir do |dir|
          yield [write_file(dir, "orders.rb"), write_file(dir, "invoices.rb")]
        end
      end

      def write_file(dir, name)
        File.join(dir, name).tap { |path| File.write(path, branching_source) }
      end

      def branching_source
        "case order.status\nwhen \"pending\"\n  nil\nwhen \"paid\", \"cancelled\"\n  nil\nend\n"
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
