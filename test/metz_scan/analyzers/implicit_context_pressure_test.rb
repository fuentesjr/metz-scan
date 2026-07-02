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

      def spree_current_store_sources
        { "app/controllers/orders_controller.rb" => spree_current_store_reader_source,
          "app/jobs/sync_order_job.rb" => spree_current_store_reader_source,
          "app/services/order_audit.rb" => spree_current_store_writer_source }
      end

      def spree_current_store_reader_source
        <<~RUBY
          class OrdersController
            def create
              Spree::Current.store
            end
          end
        RUBY
      end

      def spree_current_store_writer_source
        <<~RUBY
          class OrderAudit
            def call
              Spree::Current.store = store
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

      def namespaced_current_lifecycle_sources
        { "app/controllers/orders_controller.rb" => namespaced_current_lifecycle_source,
          "app/jobs/sync_order_job.rb" => namespaced_current_lifecycle_source,
          "app/services/order_audit.rb" => namespaced_current_lifecycle_source }
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

      def namespaced_current_lifecycle_source
        <<~RUBY
          class OrdersController
            def create
              Spree::Current.reset
              Spree::Current.set(store: store) { nil }
            end
          end
        RUBY
      end
    end

    module ImplicitContextPressureThreadCurrentFixtures
      def thread_current_account_sources
        { "app/controllers/orders_controller.rb" => thread_current_writer_source,
          "app/jobs/sync_order_job.rb" => thread_current_reader_source("SyncOrderJob", "perform"),
          "app/services/order_audit.rb" => thread_current_reader_source("OrderAudit", "call") }
      end

      def thread_current_writer_source
        <<~RUBY
          class OrdersController
            def create
              Thread.current[:account] = account
            end
          end
        RUBY
      end

      def thread_current_reader_source(class_name, method_name)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Thread.current[:account]
            end
          end
        RUBY
      end

      def dynamic_thread_current_sources
        { "app/controllers/orders_controller.rb" => dynamic_thread_current_source,
          "app/jobs/sync_order_job.rb" => dynamic_thread_current_source,
          "app/services/order_audit.rb" => dynamic_thread_current_source }
      end

      def dynamic_thread_current_source
        <<~RUBY
          class OrdersController
            def create
              Thread.current[current_context_key]
              Thread.current.name
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
        assert_match(/Current\.account is read and written from 3 files across 3 packages/, finding.message)
        assert_includes finding.triage_summary, "mutable application Current"
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

        assert_current_account_category_metadata(metadata)
        assert_equal %w[read write], metadata.fetch("access_modes")
        assert_equal "OrdersController#create", metadata.fetch("occurrences").first.fetch("context")
      end

      def assert_current_account_category_metadata(metadata)
        assert_equal "root_current_write", metadata.fetch("implicit_context_category")
        assert_equal "root_current_write", metadata.fetch("project_analyzer_category")
        assert_equal "root", metadata.fetch("current_receiver_scope")
        assert_equal "account", metadata.fetch("current_attribute")
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

    class ImplicitContextPressureNamespacedCurrentTest < Minitest::Test
      include ImplicitContextPressureFixtures

      def test_reports_namespaced_current_attribute_used_across_files_and_packages
        with_context_files(spree_current_store_sources) do |files|
          finding = analyze(files).first

          assert_spree_current_store_finding(finding)
          assert_spree_current_store_metadata(finding)
        end
      end

      def test_ignores_namespaced_current_lifecycle_calls
        with_context_files(namespaced_current_lifecycle_sources) do |files|
          assert_empty analyze(files)
        end
      end

      private

      def analyze(files)
        ImplicitContextPressure.new(index: FakeImplicitContextIndex.new(available: true, indexed_files: files)).call
      end

      def assert_spree_current_store_finding(finding)
        assert_equal "Spree::Current.store", finding.ambient_context
        assert_match(/Spree::Current\.store is read and written from 3 files across 3 packages/, finding.message)
        assert_includes finding.triage_summary, "namespaced Current"
      end

      def assert_spree_current_store_metadata(finding)
        assert_equal "namespaced_current_write", finding.project_analyzer_metadata.fetch("implicit_context_category")
        assert_equal "namespaced", finding.project_analyzer_metadata.fetch("current_receiver_scope")
        assert_equal "store", finding.project_analyzer_metadata.fetch("current_attribute")
        assert_equal %w[read write], finding.project_analyzer_metadata.fetch("access_modes")
        assert_equal "Spree::Current.store", finding.project_analyzer_metadata.fetch("ambient_context")
      end

      def with_context_files(sources)
        Dir.mktmpdir { |dir| yield write_context_files(dir, sources) }
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
    end

    class ImplicitContextPressureThreadCurrentTest < Minitest::Test
      include ImplicitContextPressureFixtures
      include ImplicitContextPressureThreadCurrentFixtures

      def test_reports_literal_thread_current_access_used_across_files_and_packages
        with_context_files(thread_current_account_sources) do |files|
          finding = analyze(files).first

          assert_thread_current_account_finding(finding)
          assert_thread_current_account_metadata(finding)
        end
      end

      def test_ignores_dynamic_thread_current_keys_and_named_thread_api
        with_context_files(dynamic_thread_current_sources) do |files|
          assert_empty analyze(files)
        end
      end

      private

      def analyze(files)
        ImplicitContextPressure.new(index: FakeImplicitContextIndex.new(available: true, indexed_files: files)).call
      end

      def assert_thread_current_account_finding(finding)
        assert_equal "Thread.current[:account]", finding.ambient_context
        assert_match(/Thread\.current\[:account\] is read and written from 3 files across 3 packages/,
                     finding.message)
        assert_includes finding.triage_summary, "Thread.current"
        assert_includes finding.why_it_matters, "thread-local"
      end

      def assert_thread_current_account_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_equal "thread_current_write", metadata.fetch("implicit_context_category")
        assert_equal "thread_current_write", metadata.fetch("project_analyzer_category")
        assert_thread_current_account_detail_metadata(metadata)
      end

      def assert_thread_current_account_detail_metadata(metadata)
        assert_equal "thread_current", metadata.fetch("ambient_context_kind")
        assert_equal "account", metadata.fetch("thread_current_key")
        assert_equal %w[read write], metadata.fetch("access_modes")
      end

      def with_context_files(sources)
        Dir.mktmpdir { |dir| yield write_context_files(dir, sources) }
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
    end
  end
end
