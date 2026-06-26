# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerPackageDependencyTest < Minitest::Test
      EXTERNAL_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/controllers/refunds_controller.rb", 11],
        ["app/jobs/capture_payment_job.rb", 12],
        ["app/jobs/reconcile_payment_job.rb", 13]
      ].freeze

      def test_merges_package_dependency_pressure_findings_from_project_index
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: package_dependency_index)

        assert_package_dependency_output(parsed)
      end

      private

      def assert_package_dependency_output(parsed)
        assert_equal 1, package_dependency_offenses(parsed).size
        assert_equal gateway_path, package_dependency_file(parsed).fetch("path")
        assert_package_dependency_metadata(package_dependency_offense(parsed))
        assert_project_analyzer_summary(parsed)
      end

      def assert_package_dependency_metadata(offense)
        assert_package_dependency_declaration_metadata(offense)
        assert_package_dependency_reference_metadata(offense)
        assert_equal "fallback", offense.dig("project_analyzer", "report_location", "line_source")
      end

      def assert_package_dependency_declaration_metadata(offense)
        assert_equal "experimental", offense.dig("project_analyzer", "status")
        assert_equal "Billing::Gateway", offense.dig("project_analyzer", "declaration", "name")
        assert_equal "app/services", offense.dig("project_analyzer", "declared_package")
      end

      def assert_package_dependency_reference_metadata(offense)
        assert_equal 4, offense.dig("project_analyzer", "referring_file_count")
        assert_equal %w[app/controllers app/jobs], offense.dig("project_analyzer", "referring_packages")
      end

      def assert_project_analyzer_summary(parsed)
        summary = parsed.fetch("summary").fetch("project_analyzers")

        assert_equal 1, summary.fetch("finding_count")
        assert_equal 1, summary.fetch("offense_count")
        assert_equal "MetzProject/PackageDependencyPressure", summary.fetch("rules").first.fetch("cop_name")
      end

      def package_dependency_offense(parsed)
        package_dependency_offenses(parsed).first
      end

      def package_dependency_offenses(parsed)
        offenses(parsed).select do |candidate|
          candidate.fetch("cop_name") == "MetzProject/PackageDependencyPressure"
        end
      end

      def package_dependency_file(parsed)
        parsed.fetch("files").find do |file|
          file.fetch("offenses").any? do |offense|
            offense.fetch("cop_name") == "MetzProject/PackageDependencyPressure"
          end
        end
      end

      def offenses(parsed)
        parsed.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def package_dependency_index
        ProjectAnalyzerRunnerPackageDependencyIndex.new(
          declarations: gateway_declarations,
          references: { "Billing::Gateway" => external_references }
        )
      end

      def gateway_declarations
        [ProjectIndex::Declaration.new(name: "Billing::Gateway", path: gateway_path, kind: :class)]
      end

      def external_references
        EXTERNAL_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def reference(path, line)
        ProjectIndex::Reference.new(name: "Billing::Gateway", path: "/project/#{path}", line: line, column: 8)
      end

      def gateway_path
        "/project/app/services/billing/gateway.rb"
      end
    end

    class ProjectAnalyzerRunnerPackageDependencyIndex
      def initialize(declarations:, references:)
        @declarations = declarations
        @references = references
      end

      attr_reader :declarations

      def backend_name = :fake

      def available? = true

      def indexed_files = []

      def descendants_of(_name) = []

      def constant_references_to(name) = @references.fetch(name, [])
    end
  end
end
