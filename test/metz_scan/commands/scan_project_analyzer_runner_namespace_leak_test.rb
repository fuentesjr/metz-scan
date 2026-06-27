# frozen_string_literal: true

require "minitest/autorun"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerNamespaceLeakTest < Minitest::Test
      EXTERNAL_REFERENCE_PATHS = [
        ["app/controllers/orders_controller.rb", 10],
        ["app/jobs/capture_payment_job.rb", 11],
        ["app/mailers/receipt_mailer.rb", 12]
      ].freeze

      def test_merges_namespace_leak_pressure_findings_from_project_index
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [], index: namespace_leak_index)

        assert_namespace_leak_output(parsed)
      end

      private

      def assert_namespace_leak_output(parsed)
        assert_equal 1, namespace_leak_offenses(parsed).size
        assert_equal formatter_path, namespace_leak_file(parsed).fetch("path")
        assert_namespace_leak_metadata(namespace_leak_offense(parsed))
        assert_project_analyzer_summary(parsed)
      end

      def assert_namespace_leak_metadata(offense)
        assert_namespace_leak_identity(offense)
        assert_namespace_leak_counts(offense)
      end

      def assert_namespace_leak_identity(offense)
        assert_equal "Billing::Ledger", offense.dig("project_analyzer", "home_namespace")
        assert_equal "app/models", offense.dig("project_analyzer", "declared_package")
        assert_equal "candidate", offense.dig("project_analyzer", "status")
        assert_equal "Billing::Ledger::PrivateFormatter", offense.dig("project_analyzer", "declaration", "name")
      end

      def assert_namespace_leak_counts(offense)
        assert_equal "fallback", offense.dig("project_analyzer", "report_location", "line_source")
        assert_equal 3, offense.dig("project_analyzer", "referring_file_count")
        assert_equal %w[app/controllers app/jobs app/mailers], offense.dig("project_analyzer", "referring_packages")
      end

      def assert_project_analyzer_summary(parsed)
        summary = parsed.fetch("summary").fetch("project_analyzers")

        assert_equal 1, summary.fetch("finding_count")
        assert_equal 1, summary.fetch("offense_count")
        assert_namespace_leak_summary_rule(summary.fetch("rules").first)
      end

      def assert_namespace_leak_summary_rule(rule)
        assert_equal "MetzProject/NamespaceLeakPressure", rule.fetch("cop_name")
        assert_equal "candidate", rule.fetch("status")
        assert_equal "medium", rule.fetch("confidence")
      end

      def namespace_leak_offense(parsed)
        namespace_leak_offenses(parsed).first
      end

      def namespace_leak_offenses(parsed)
        offenses(parsed).select do |candidate|
          candidate.fetch("cop_name") == "MetzProject/NamespaceLeakPressure"
        end
      end

      def namespace_leak_file(parsed)
        parsed.fetch("files").find do |file|
          file.fetch("offenses").any? do |offense|
            offense.fetch("cop_name") == "MetzProject/NamespaceLeakPressure"
          end
        end
      end

      def offenses(parsed)
        parsed.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def namespace_leak_index
        ProjectAnalyzerRunnerNamespaceLeakIndex.new(
          declarations: formatter_declarations,
          references: { "Billing::Ledger::PrivateFormatter" => external_references }
        )
      end

      def formatter_declarations
        [ProjectIndex::Declaration.new(name: "Billing::Ledger::PrivateFormatter", path: formatter_path, kind: :class)]
      end

      def external_references
        EXTERNAL_REFERENCE_PATHS.map { |path, line| reference(path, line) }
      end

      def reference(path, line)
        ProjectIndex::Reference.new(name: "Billing::Ledger::PrivateFormatter", path: "/project/#{path}",
                                    line: line, column: 8)
      end

      def formatter_path
        "/project/app/models/billing/ledger/private_formatter.rb"
      end
    end

    class ProjectAnalyzerRunnerNamespaceLeakIndex
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
