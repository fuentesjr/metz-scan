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

    module RepeatedQueryCriteriaScopeFixtures
      def scoped_order_query_sources
        { "app/controllers/orders_controller.rb" => scoped_order_query_source("OrdersController", "index"),
          "app/jobs/sync_orders_job.rb" => scoped_order_query_source("SyncOrdersJob", "perform"),
          "app/services/order_report.rb" => scoped_order_query_source("OrderReport", "call") }
      end

      def scoped_order_query_source(class_name, method_name)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Order.active.where(account_id: account.id, status: "open")
            end
          end
        RUBY
      end

      def mixed_scoped_and_bare_order_sources
        { "app/controllers/orders_controller.rb" => scoped_order_query_source("OrdersController", "index"),
          "app/jobs/sync_orders_job.rb" => repeated_order_query_source("SyncOrdersJob", "perform"),
          "app/services/order_report.rb" => repeated_order_query_source("OrderReport", "call") }
      end

      def dynamic_scope_query_sources
        { "app/controllers/orders_controller.rb" => dynamic_scope_query_source,
          "app/jobs/sync_orders_job.rb" => dynamic_scope_query_source,
          "app/services/order_report.rb" => dynamic_scope_query_source }
      end

      def dynamic_scope_query_source
        <<~RUBY
          class OrdersController
            def index
              Order.public_send(scope_name).where(account_id: account.id, status: "open")
              relation.where(account_id: account.id, status: "open")
            end
          end
        RUBY
      end
    end

    module RepeatedQueryCriteriaFinderFixtures
      def repeated_finder_query_sources(query_method = "find_by")
        { "app/controllers/posts_controller.rb" => finder_query_source("PostsController", "show", query_method),
          "app/jobs/sync_posts_job.rb" => finder_query_source("SyncPostsJob", "perform", query_method),
          "app/services/post_lookup.rb" => finder_query_source("PostLookup", "call", query_method) }
      end

      def finder_query_source(class_name, method_name, query_method)
        <<~RUBY
          class #{class_name}
            def #{method_name}
              Post.#{query_method}(topic_id: topic.id, post_number: params[:post_number])
            end
          end
        RUBY
      end

      def mixed_finder_and_where_sources
        { "app/controllers/posts_controller.rb" => "Post.find_by(topic_id: topic.id, post_number: 1)\n",
          "app/jobs/sync_posts_job.rb" => "Post.where(topic_id: topic.id, post_number: 1)\n",
          "app/services/post_report.rb" => "Post.where(topic_id: topic.id, post_number: 1)\n" }
      end

      def single_key_finder_sources
        repeated_sources_for("Post.find_by(topic_id: topic.id)")
      end

      def dynamic_finder_sources
        repeated_sources_for("Post.find_by(query_attributes)")
      end
    end

    module RepeatedQueryCriteriaNegativeWhereFixtures
      def negative_where_sources
        repeated_sources_for("Order.active.where.not(account_id: account.id, status: \"closed\")")
      end

      def mixed_positive_and_negative_where_sources
        { "app/controllers/orders_controller.rb" => "Order.active.where(account_id: account.id, status: \"closed\")\n",
          "app/jobs/sync_orders_job.rb" => "Order.active.where.not(account_id: account.id, status: \"closed\")\n",
          "app/services/order_report.rb" => "Order.active.where(account_id: account.id, status: \"closed\")\n" }
      end

      def single_key_negative_where_sources
        repeated_sources_for("Order.where.not(account_id: account.id)")
      end

      def dynamic_negative_where_sources
        repeated_sources_for("Order.where.not(\"account_id = ? AND status = ?\", account.id, \"closed\")")
      end
    end

    module RepeatedQueryCriteriaSmallSourceFixtures
      def repeated_sources_for(expression)
        { "app/controllers/orders_controller.rb" => expression,
          "app/jobs/sync_orders_job.rb" => expression,
          "app/services/order_report.rb" => expression }
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

    class RepeatedQueryCriteriaScopeChainTest < Minitest::Test
      include RepeatedQueryCriteriaFixtures
      include RepeatedQueryCriteriaScopeFixtures

      def test_reports_constant_root_scope_chain_query_criteria
        with_query_files(scoped_order_query_sources) do |files|
          assert_scope_chain_query_finding(analyze(files).first)
        end
      end

      def test_does_not_group_scope_chains_with_bare_receivers
        with_query_files(mixed_scoped_and_bare_order_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_dynamic_scope_chains_and_non_constant_receivers
        with_query_files(dynamic_scope_query_sources) do |files|
          assert_empty analyze(files)
        end
      end

      private

      def analyze(files)
        RepeatedQueryCriteria.new(index: FakeRepeatedQueryIndex.new(available: true, indexed_files: files)).call
      end

      def assert_scope_chain_query_finding(finding)
        assert_equal "Order.active.where(account_id, status)", finding.query
        assert_equal "Order.active", finding.receiver
        assert_scope_chain_query_metadata(finding)
        assert_match(/Order\.active\.where\(account_id, status\) repeats association-scoped query criteria/,
                     finding.message)
      end

      def assert_scope_chain_query_metadata(finding)
        assert_equal "scope_chain", finding.project_analyzer_metadata.fetch("receiver_shape")
        assert_equal %w[account_id status], finding.criteria_keys
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

    class RepeatedQueryCriteriaFinderTest < Minitest::Test
      include RepeatedQueryCriteriaFixtures
      include RepeatedQueryCriteriaFinderFixtures
      include RepeatedQueryCriteriaSmallSourceFixtures

      def test_reports_repeated_supported_finder_hash_criteria
        supported_finder_query_methods.each { |query_method| assert_finder_query_reported(query_method) }
      end

      def test_does_not_group_finders_with_where_queries
        with_query_files(mixed_finder_and_where_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_single_key_finder_queries
        with_query_files(single_key_finder_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_dynamic_finder_queries
        with_query_files(dynamic_finder_sources) do |files|
          assert_empty analyze(files)
        end
      end

      private

      def analyze(files)
        RepeatedQueryCriteria.new(index: FakeRepeatedQueryIndex.new(available: true, indexed_files: files)).call
      end

      def supported_finder_query_methods
        %w[find_by find_or_initialize_by find_or_create_by]
      end

      def assert_finder_query_reported(query_method)
        with_query_files(repeated_finder_query_sources(query_method)) do |files|
          assert_finder_query_finding(analyze(files).first, query_method)
        end
      end

      def assert_finder_query_finding(finding, query_method)
        assert_equal "Post.#{query_method}(post_number, topic_id)", finding.query
        assert_equal "finder", finding.project_analyzer_metadata.fetch("query_operation")
        assert_equal query_method, finding.project_analyzer_metadata.fetch("query_method")
        assert_includes finding.message, "repeats finder query criteria"
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

    class RepeatedQueryCriteriaNegativeWhereTest < Minitest::Test
      include RepeatedQueryCriteriaNegativeWhereFixtures
      include RepeatedQueryCriteriaSmallSourceFixtures

      def test_reports_repeated_negative_where_hash_criteria
        with_query_files(negative_where_sources) do |files|
          assert_negative_where_finding(analyze(files).first)
        end
      end

      def test_does_not_group_negative_and_positive_where_queries
        with_query_files(mixed_positive_and_negative_where_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_single_key_negative_where_queries
        with_query_files(single_key_negative_where_sources) do |files|
          assert_empty analyze(files)
        end
      end

      def test_ignores_dynamic_negative_where_queries
        with_query_files(dynamic_negative_where_sources) do |files|
          assert_empty analyze(files)
        end
      end

      private

      def analyze(files)
        RepeatedQueryCriteria.new(index: FakeRepeatedQueryIndex.new(available: true, indexed_files: files)).call
      end

      def assert_negative_where_finding(finding)
        assert_equal "Order.active.where.not(account_id, status)", finding.query
        assert_equal "scope_chain", finding.project_analyzer_metadata.fetch("receiver_shape")
        assert_equal "negative_filter", finding.project_analyzer_metadata.fetch("query_operation")
        assert_equal "where.not", finding.project_analyzer_metadata.fetch("query_method")
        assert_includes finding.message, "repeats negative association-scoped query criteria"
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
