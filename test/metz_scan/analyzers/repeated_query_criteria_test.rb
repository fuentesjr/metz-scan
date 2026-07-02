# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"

require "metz_scan/analyzers/repeated_query_criteria"

module MetzScan
  module Analyzers
    module RepeatedQueryCriteriaFixtures
      def repeated_order_query_sources
        { "app/controllers/orders_controller.rb" => repeated_order_query_source("OrdersController", "index"),
          "app/jobs/sync_orders_job.rb" => repeated_order_query_source("SyncOrdersJob", "perform"),
          "app/services/order_report.rb" => repeated_order_query_source("OrderReport", "call") }
      end

      def repeated_order_query_source(class_name, method_name)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Order.where(account_id: account.id, status: "open")
            end
          end
        RUBY
      end

      def below_threshold_sources
        repeated_order_query_sources.slice("app/controllers/orders_controller.rb", "app/jobs/sync_orders_job.rb")
      end

      def mixed_query_sources
        { "app/controllers/orders_controller.rb" => repeated_order_query_source("OrdersController", "index"),
          "app/jobs/sync_orders_job.rb" => invoice_query_source,
          "app/services/order_report.rb" => order_query_with_different_keys_source }
      end

      def invoice_query_source
        <<~RUBY
          class SyncOrdersJob
            def perform
              Invoice.where(account_id: account.id, status: "open")
            end
          end
        RUBY
      end

      def order_query_with_different_keys_source
        <<~RUBY
          class OrderReport
            def call
              Order.where(account_id: account.id, state: "open")
            end
          end
        RUBY
      end

      def single_key_query_sources
        { "app/controllers/orders_controller.rb" => single_key_query_source,
          "app/jobs/sync_orders_job.rb" => single_key_query_source,
          "app/services/order_report.rb" => single_key_query_source }
      end

      def single_key_query_source
        <<~RUBY
          class OrdersController
            def index
              Order.where(account_id: account.id)
            end
          end
        RUBY
      end

      def dynamic_query_sources
        { "app/controllers/orders_controller.rb" => dynamic_query_source,
          "app/jobs/sync_orders_job.rb" => dynamic_query_source,
          "app/services/order_report.rb" => dynamic_query_source }
      end

      def polymorphic_query_sources
        { "app/controllers/comments_controller.rb" => polymorphic_query_source("CommentsController", "index"),
          "app/jobs/sync_comments_job.rb" => polymorphic_query_source("SyncCommentsJob", "perform"),
          "app/services/comment_report.rb" => polymorphic_query_source("CommentReport", "call") }
      end

      def dynamic_query_source
        <<~RUBY
          class OrdersController
            def index
              Order.where("account_id = ? AND status = ?", account.id, "open")
            end
          end
        RUBY
      end

      def polymorphic_query_source(class_name, method_name)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Comment.where(commentable_id: record.id, commentable_type: record.class.name)
            end
          end
        RUBY
      end

      def test_query_sources
        repeated_order_query_sources.merge(
          "spec/services/order_report_spec.rb" => repeated_order_query_source("OrderReportSpec", "call")
        )
      end
    end

    class RepeatedQueryCriteriaTest < Minitest::Test
      include RepeatedQueryCriteriaFixtures

      def test_reports_query_criteria_repeated_across_files_and_packages
        with_query_files(repeated_order_query_sources) do |files|
          finding = analyze(files).first

          assert_order_query_finding(finding)
          assert_order_query_metadata(finding)
        end
      end

      def test_skips_repeated_query_below_file_threshold
        with_query_files(below_threshold_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_does_not_group_different_receivers_or_criteria_keys
        with_query_files(mixed_query_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_single_key_queries
        with_query_files(single_key_query_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_dynamic_where_strings
        with_query_files(dynamic_query_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_test_references
        with_query_files(test_query_sources) do |files|
          finding = analyze(files).first

          assert_equal 3, finding.referring_files.size
          refute_includes finding.referring_files, "spec/services/order_report_spec.rb"
        end
      end

      def test_uses_explicit_paths_when_index_is_unavailable
        with_query_files(repeated_order_query_sources) do |files|
          finding = RepeatedQueryCriteria.new(paths: files, index: fake_index([], available: false)).call.first

          assert_equal "Order.where(account_id, status)", finding.query
        end
      end

      private

      def analyze(files)
        RepeatedQueryCriteria.new(index: fake_index(files)).call
      end

      def assert_order_query_finding(finding)
        assert_order_query_identity(finding)
        assert_order_query_signature(finding)
        assert_order_query_references(finding)
      end

      def assert_order_query_identity(finding)
        assert_equal "MetzProject/RepeatedQueryCriteria", finding.rule_id
        assert_equal "candidate", finding.project_analyzer_status
        assert_equal "medium", finding.confidence
        assert_equal "manual review", finding.triage_severity
      end

      def assert_order_query_signature(finding)
        assert_equal "Order.where(account_id, status)", finding.query
        assert_equal %w[account_id status], finding.criteria_keys
      end

      def assert_order_query_references(finding)
        assert_equal %w[app/controllers app/jobs app/services], finding.referring_packages
        assert_equal 3, finding.occurrences.size
        assert_equal 1, finding.report_occurrences.size
      end

      def assert_order_query_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_order_query_category_metadata(metadata)
        assert_equal "Order", metadata.fetch("receiver")
        assert_equal %w[account_id status], metadata.fetch("criteria_keys")
        assert_equal "OrdersController#index", metadata.fetch("occurrences").first.fetch("context")
      end

      def assert_order_query_category_metadata(metadata)
        assert_equal "scoped_association_where_criteria", metadata.fetch("repeated_query_category")
        assert_equal "scoped_association_where_criteria", metadata.fetch("project_analyzer_category")
      end

      def with_query_files(sources)
        Dir.mktmpdir do |dir|
          yield write_query_files(dir, sources)
        end
      end

      def write_query_files(dir, sources)
        sources.map { |relative_path, source| write_query_file(dir, relative_path, source) }
      end

      def write_query_file(dir, relative_path, source)
        File.join(dir, relative_path).tap do |path|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, source)
        end
      end

      def fake_index(files, available: true)
        FakeRepeatedQueryIndex.new(available: available, indexed_files: files)
      end
    end

    class RepeatedQueryCriteriaCategoryTest < Minitest::Test
      include RepeatedQueryCriteriaFixtures

      def test_classifies_repeated_polymorphic_query_criteria
        with_query_files(polymorphic_query_sources) do |files|
          assert_polymorphic_query_finding(analyze(files).first)
        end
      end

      private

      def analyze(files)
        RepeatedQueryCriteria.new(index: FakeRepeatedQueryIndex.new(available: true, indexed_files: files)).call
      end

      def assert_polymorphic_query_finding(finding)
        assert_equal "polymorphic_where_criteria",
                     finding.project_analyzer_metadata.fetch("repeated_query_category")
        assert_includes finding.message, "polymorphic query criteria"
        assert_includes finding.triage_summary, "polymorphic query"
        assert_includes finding.why_it_matters, "polymorphic"
      end

      def with_query_files(sources)
        Dir.mktmpdir { |dir| yield write_query_files(dir, sources) }
      end

      def write_query_files(dir, sources)
        sources.map { |relative_path, source| write_query_file(dir, relative_path, source) }
      end

      def write_query_file(dir, relative_path, source)
        File.join(dir, relative_path).tap do |path|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, source)
        end
      end
    end

    class FakeRepeatedQueryIndex
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
