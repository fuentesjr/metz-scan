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

      def test_uses_index_declarations_as_base_candidates_when_unconfigured
        finding = InheritanceDescendants.new(index: fake_index, minimum_descendants: 2).call.first

        assert_equal "ApplicationController", finding.base_name
        assert_equal %w[AdminController OrdersController], finding.descendants
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

      def test_filters_core_and_synthetic_declarations_from_auto_discovered_candidates
        finding = InheritanceDescendants.new(index: noisy_index, minimum_descendants: 2).call.first

        assert_equal "ApplicationRecord", finding.base_name
        assert_equal %w[Account Order], finding.descendants
      end

      def test_uses_first_descendant_location_when_base_declaration_has_no_path
        finding = InheritanceDescendants.new(index: missing_base_path_index, base_names: "ApplicationController",
                                             minimum_descendants: 2).call.first

        assert_equal ["/app/admin_controller.rb"], finding.occurrences.map(&:path)
      end

      private

      def analyze_fake_index
        InheritanceDescendants.new(index: fake_index, base_names: "ApplicationController",
                                   minimum_descendants: 2).call
      end

      def assert_finding_metadata(finding)
        assert_finding_identity(finding)
        assert_finding_triage(finding)
        refute_empty finding.suggested_next_moves
      end

      def assert_finding_identity(finding)
        assert_equal "MetzProject/DeepInheritanceTree", finding.rule_id
        assert_equal "ApplicationController", finding.base_name
        assert_includes finding.message, "ApplicationController has 2 descendants"
      end

      def assert_finding_triage(finding)
        assert_equal "experimental", finding.project_analyzer_status
        assert_equal "early", finding.confidence
        assert_equal "manual review", finding.triage_severity
        assert_match(/inheritance/i, finding.triage_summary)
        assert_project_analyzer_metadata(finding)
      end

      def assert_project_analyzer_metadata(finding)
        assert_equal "ApplicationController", finding.project_analyzer_metadata.fetch("base_name")
        assert_equal expected_descendant_locations, finding.project_analyzer_metadata.fetch("descendant_locations")
      end

      def assert_finding_descendants(finding)
        assert_equal %w[AdminController OrdersController], finding.descendants
        assert_equal fake_paths, finding.locations.map(&:path)
        assert_equal ["/app/application_controller.rb"], finding.occurrences.map(&:path)
      end

      def expected_descendant_locations
        [{ "name" => "AdminController", "path" => "/app/admin_controller.rb" },
         { "name" => "OrdersController", "path" => "/app/orders_controller.rb" }]
      end

      def fake_index
        FakeIndex.new(available: true, descendants: fake_descendants, declarations: fake_declarations)
      end

      def missing_base_path_index
        declarations = fake_declarations.reject { |declaration| declaration.name == "ApplicationController" }
        FakeIndex.new(available: true, descendants: fake_descendants, declarations: declarations)
      end

      def fake_descendants
        { "ApplicationController" => %w[OrdersController AdminController] }
      end

      def fake_declarations
        [declaration("ApplicationController", "/app/application_controller.rb")] +
          fake_paths.map { |path| declaration(declaration_name(path), path) }
      end

      def fake_paths
        ["/app/admin_controller.rb", "/app/orders_controller.rb"]
      end

      def declaration_name(path) = path.include?("admin") ? "AdminController" : "OrdersController"

      def unavailable_index
        FakeIndex.new(available: false, descendants: {}, declarations: [])
      end

      def noisy_index
        FakeIndex.new(available: true, descendants: noisy_descendants, declarations: noisy_declarations)
      end

      def noisy_descendants
        { "BasicObject" => %w[Class Module Object],
          "ApplicationRecord" => ["ApplicationRecord::<ApplicationRecord>", "Order", "Account"] }
      end

      def noisy_declarations
        noisy_names.map { |name| declaration(name, "/app/#{name}.rb") }
      end

      def noisy_names
        %w[BasicObject Class Module Object ApplicationRecord ApplicationRecord::<ApplicationRecord> Order Account]
      end

      def declaration(name, path, kind = nil) = ProjectIndex::Declaration.new(name: name, path: path, kind: kind)
    end

    class InheritanceDescendantsRootSelectionTest < Minitest::Test
      def test_auto_discovery_ignores_known_non_class_roots
        findings = InheritanceDescendants.new(index: kinded_index, minimum_descendants: 2).call

        assert_equal ["ApplicationController"], findings.map(&:base_name)
      end

      def test_auto_discovery_ignores_roots_without_declaration_paths
        findings = InheritanceDescendants.new(index: unlocated_root_index, minimum_descendants: 2).call

        assert_equal ["ApplicationController"], findings.map(&:base_name)
      end

      def test_configured_base_names_can_still_report_known_non_class_roots
        finding = InheritanceDescendants.new(index: kinded_index, base_names: "RequestTimeouts",
                                             minimum_descendants: 2).call.first

        assert_equal "RequestTimeouts", finding.base_name
      end

      private

      def kinded_index
        FakeIndex.new(available: true, descendants: kinded_descendants, declarations: kinded_declarations)
      end

      def kinded_descendants
        { "ApplicationController" => %w[AdminController OrdersController],
          "RequestTimeouts" => %w[AdminController OrdersController] }
      end

      def kinded_declarations
        [declaration("ApplicationController", "/app/application_controller.rb", :class),
         declaration("RequestTimeouts", "/app/controllers/concerns/request_timeouts.rb", :module),
         declaration("AdminController", "/app/admin_controller.rb", :class),
         declaration("OrdersController", "/app/orders_controller.rb", :class)]
      end

      def unlocated_root_index
        FakeIndex.new(available: true, descendants: unlocated_root_descendants,
                      declarations: unlocated_root_declarations)
      end

      def unlocated_root_descendants
        kinded_descendants.merge("ViteRails::TagHelpers" => %w[AdminController OrdersController])
      end

      def unlocated_root_declarations
        kinded_declarations + [declaration("ViteRails::TagHelpers", nil, nil)]
      end

      def declaration(name, path, kind = nil)
        ProjectIndex::Declaration.new(name: name, path: path, kind: kind)
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
        InheritanceDescendants.new(index: index, base_names: "ProjectBase", minimum_descendants: 1).call.first
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
