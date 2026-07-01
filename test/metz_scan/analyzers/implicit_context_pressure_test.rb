# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"

require "metz_scan/analyzers/implicit_context_pressure"

module MetzScan
  module Analyzers
    module ImplicitContextPressureFixtures
      def current_account_sources
        { "app/controllers/orders_controller.rb" => current_account_writer_source,
          "app/jobs/sync_order_job.rb" => current_account_reader_source("SyncOrderJob", "perform"),
          "app/services/order_audit.rb" => current_account_reader_source("OrderAudit", "call") }
      end

      def current_account_writer_source
        <<~RUBY
          class OrdersController
            def create
              Current.account = account
            end
          end
        RUBY
      end

      def current_account_reader_source(class_name, method_name)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Current.account
            end
          end
        RUBY
      end

      def below_threshold_sources
        current_account_sources.slice("app/controllers/orders_controller.rb", "app/jobs/sync_order_job.rb")
      end

      def plain_current_reader_sources
        { "app/controllers/orders_controller.rb" => plain_current_reader_source,
          "app/jobs/sync_order_job.rb" => plain_current_reader_source,
          "app/services/order_audit.rb" => plain_current_reader_source }
      end

      def plain_current_reader_source
        <<~RUBY
          class OrdersController
            def create(current)
              current.account
            end
          end
        RUBY
      end

      def test_only_current_sources
        current_account_sources.merge(
          "spec/services/order_audit_spec.rb" => current_account_reader_source("OrderAuditSpec", "call")
        )
      end

      def current_lifecycle_sources
        { "app/controllers/orders_controller.rb" => current_lifecycle_source,
          "app/jobs/sync_order_job.rb" => current_lifecycle_source,
          "app/services/order_audit.rb" => current_lifecycle_source }
      end

      def current_lifecycle_source
        <<~RUBY
          class OrdersController
            def create
              Current.reset
              Current.set(account: account) { nil }
            end
          end
        RUBY
      end
    end

    class ImplicitContextPressureTest < Minitest::Test
      include ImplicitContextPressureFixtures

      def test_reports_current_attribute_used_across_files_and_packages
        with_context_files(current_account_sources) do |files|
          finding = analyze(files).first

          assert_current_account_finding(finding)
          assert_current_account_metadata(finding)
        end
      end

      def test_skips_current_attribute_below_file_threshold
        with_context_files(below_threshold_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_plain_current_local_receiver
        with_context_files(plain_current_reader_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_test_references
        with_context_files(test_only_current_sources) do |files|
          finding = analyze(files).first

          assert_equal 3, finding.referring_files.size
          refute_includes finding.referring_files, "spec/services/order_audit_spec.rb"
        end
      end

      def test_ignores_current_lifecycle_calls
        with_context_files(current_lifecycle_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_uses_explicit_paths_when_index_is_unavailable
        with_context_files(current_account_sources) do |files|
          finding = ImplicitContextPressure.new(paths: files, index: fake_index([], available: false)).call.first

          assert_equal "Current.account", finding.ambient_context
        end
      end

      private

      def analyze(files)
        ImplicitContextPressure.new(index: fake_index(files)).call
      end

      def assert_current_account_finding(finding)
        assert_current_account_identity(finding)
        assert_current_account_references(finding)
        assert_match(/Current\.account is accessed from 3 files across 3 packages/, finding.message)
        refute_empty finding.suggested_next_moves
      end

      def assert_current_account_identity(finding)
        assert_equal "MetzProject/ImplicitContextPressure", finding.rule_id
        assert_equal "candidate", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "manual review", finding.triage_severity
        assert_equal "Current.account", finding.ambient_context
      end

      def assert_current_account_references(finding)
        assert_equal %w[app/controllers app/jobs app/services], finding.referring_packages
        assert_equal 3, finding.occurrences.size
        assert_equal 1, finding.report_occurrences.size
      end

      def assert_current_account_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_equal "current_attributes", metadata.fetch("implicit_context_category")
        assert_equal %w[read write], metadata.fetch("access_modes")
        assert_equal "OrdersController#create", metadata.fetch("occurrences").first.fetch("context")
      end

      def with_context_files(sources)
        Dir.mktmpdir do |dir|
          yield write_context_files(dir, sources)
        end
      end

      def write_context_files(dir, sources)
        sources.map { |relative_path, source| write_context_file(dir, relative_path, source) }
      end

      def write_context_file(dir, relative_path, source)
        File.join(dir, relative_path).tap do |path|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, source)
        end
      end

      def fake_index(files, available: true)
        FakeImplicitContextIndex.new(available: available, indexed_files: files)
      end
    end

    class FakeImplicitContextIndex
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
