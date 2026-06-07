# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/inheritance_descendants"

module MetzScan
  module Analyzers
    class InheritanceDescendantsTest < Minitest::Test
      def test_reports_configured_base_when_descendant_count_meets_threshold
        finding = analyze_fake_index.first

        assert_finding_metadata(finding)
        assert_finding_descendants(finding)
      end

      def test_skips_configured_base_below_threshold
        analyzer = InheritanceDescendants.new(index: fake_index, base_names: "ApplicationController",
                                              minimum_descendants: 3)

        assert_empty analyzer.call
      end

      def test_skips_when_index_is_unavailable
        analyzer = InheritanceDescendants.new(index: unavailable_index, base_names: "ApplicationController")

        assert_empty analyzer.call
      end

      private

      def analyze_fake_index
        InheritanceDescendants.new(index: fake_index, base_names: "ApplicationController",
                                   minimum_descendants: 2).call
      end

      def assert_finding_metadata(finding)
        assert_equal "MetzProject/DeepInheritanceTree", finding.rule_id
        assert_equal "ApplicationController", finding.base_name
        assert_includes finding.message, "ApplicationController has 2 descendants"
        refute_empty finding.suggested_next_moves
      end

      def assert_finding_descendants(finding)
        assert_equal %w[AdminController OrdersController], finding.descendants
        assert_equal fake_paths, finding.locations.map(&:path)
      end

      def fake_index
        FakeIndex.new(available: true, descendants: fake_descendants, declarations: fake_declarations)
      end

      def fake_descendants
        { "ApplicationController" => %w[OrdersController AdminController] }
      end

      def fake_declarations
        fake_paths.map { |path| ProjectIndex::Declaration.new(name: declaration_name(path), path: path) }
      end

      def fake_paths
        ["/app/admin_controller.rb", "/app/orders_controller.rb"]
      end

      def declaration_name(path)
        path.include?("admin") ? "AdminController" : "OrdersController"
      end

      def unavailable_index
        FakeIndex.new(available: false, descendants: {}, declarations: [])
      end
    end

    class InheritanceDescendantsRubydexTest < Minitest::Test
      def test_reports_descendants_from_rubydex_project_index
        skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

        assert_equal ["ProjectChild"], rubydex_finding.descendants
      end

      private

      def rubydex_finding
        Dir.mktmpdir { |dir| rubydex_finding_for(dir) }
      end

      def rubydex_finding_for(dir)
        write_inheritance_fixture(dir)
        index = ProjectIndex.build([dir], backend: :rubydex)
        InheritanceDescendants.new(index: index, base_names: "ProjectBase").call.first
      end

      def write_inheritance_fixture(dir)
        File.write(File.join(dir, "inheritance.rb"), "class ProjectBase; end\nclass ProjectChild < ProjectBase; end\n")
      end
    end

    class FakeIndex
      def initialize(available:, descendants:, declarations:)
        @available = available
        @descendants = descendants
        @declarations = declarations
      end

      attr_reader :declarations

      def backend_name = :fake

      def available? = @available

      def descendants_of(name) = @descendants.fetch(name, [])
    end
  end
end
