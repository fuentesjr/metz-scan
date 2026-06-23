# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/service_soup"

module MetzScan
  module Analyzers
    module ServiceSoupFixtureSources
      def service_soup_source
        <<~RUBY
          class OrdersController
            def create
              ValidateOrder.call(order)
              ReserveInventory.call(order)
              CapturePayment.new(order).call
            end
          end
        RUBY
      end

      def plain_callable_source
        <<~RUBY
          class OrdersController
            def create
              validator.call(order)
              notifier.call(order)
              presenter.call(order)
            end
          end
        RUBY
      end

      def below_threshold_source
        <<~RUBY
          class OrdersController
            def create
              ValidateOrder.call(order)
              CapturePayment.call(order)
            end
          end
        RUBY
      end

      def repeated_same_service_source
        <<~RUBY
          class OrdersController
            def create
              ValidateOrder.call(order)
              ValidateOrder.call(order)
              ValidateOrder.new(order).call
            end
          end
        RUBY
      end

      def perform_service_source
        <<~RUBY
          class Inboxes::FetchImapEmailsJob
            def process_email_for_channel(channel, interval)
              if channel.microsoft?
                Imap::MicrosoftFetchEmailService.new(channel: channel, interval: interval).perform
              elsif channel.google?
                Imap::GoogleFetchEmailService.new(channel: channel, interval: interval).perform
              else
                Imap::FetchEmailService.new(channel: channel, interval: interval).perform
              end
            end
          end
        RUBY
      end

      def nested_scope_source
        <<~RUBY
          class OrdersController
            def create
              ValidateOrder.call(order)

              helper = Class.new do
                def call
                  ReserveInventory.call(order)
                  CapturePayment.call(order)
                end
              end
            end
          end
        RUBY
      end
    end

    class ServiceSoupTest < Minitest::Test
      include ServiceSoupFixtureSources

      def test_reports_many_service_style_calls_in_one_workflow
        with_service_files([service_soup_source]) do |files|
          finding = analyze(files).first

          assert_reported_service_soup_finding(finding)
        end
      end

      def test_ignores_plain_callable_objects
        with_service_files([plain_callable_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_skips_workflows_below_threshold
        with_service_files([below_threshold_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_repeated_calls_to_same_service_do_not_satisfy_threshold
        with_service_files([repeated_same_service_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_nested_workflow_scopes_do_not_leak_into_outer_method
        with_service_files([nested_scope_source]) do |files|
          assert_empty analyze(files)
        end
      end

      def test_uses_explicit_paths_when_index_is_unavailable
        with_service_files([service_soup_source]) do |files|
          finding = ServiceSoup.new(paths: files, index: fake_index([], available: false)).call.first

          assert_equal "OrdersController#create", finding.workflow
        end
      end

      def test_reports_service_soup_from_tiny_rails_fixture
        finding = ServiceSoup.new(paths: [service_soup_fixture_path]).call.first

        assert_rails_fixture_finding(finding)
        assert_equal service_soup_fixture_controller, finding.occurrences.first.path
      end

      private

      def analyze(files)
        ServiceSoup.new(index: fake_index(files)).call
      end

      def assert_reported_service_soup_finding(finding)
        assert_service_soup_finding(finding)
        assert_service_soup_metadata(finding)
        refute_empty finding.suggested_next_moves
      end

      def assert_service_soup_finding(finding)
        assert_equal "MetzProject/ServiceSoup", finding.rule_id
        assert_equal "OrdersController#create", finding.workflow
        assert_equal %w[CapturePayment ReserveInventory ValidateOrder], finding.services
        assert_equal 3, finding.occurrences.size
        assert_includes finding.message, "OrdersController#create coordinates 3 distinct services"
      end

      def assert_service_soup_metadata(finding)
        metadata = finding.project_analyzer_metadata

        assert_workflow_metadata(metadata.fetch("workflow"))
        assert_service_call_metadata(metadata.fetch("services"))
      end

      def assert_workflow_metadata(workflow)
        assert_equal "OrdersController#create", workflow.fetch("context")
        assert_equal "OrdersController", workflow.fetch("enclosing")
        assert_equal "#create", workflow.fetch("method")
        assert_equal "def create", workflow.fetch("expression")
      end

      def assert_service_call_metadata(services)
        assert_equal(
          ["ValidateOrder.call(order)", "ReserveInventory.call(order)", "CapturePayment.new(order).call"],
          services.map { |service| service.fetch("expression") }
        )
      end

      def assert_rails_fixture_finding(finding)
        assert_equal "MetzProject/ServiceSoup", finding.rule_id
        assert_equal "OrdersController#create", finding.workflow
        assert_equal %w[CapturePayment ReserveInventory SendReceipt ValidateOrder], finding.services
      end

      def with_service_files(contents)
        Dir.mktmpdir { |dir| yield write_service_files(dir, contents) }
      end

      def write_service_files(dir, contents)
        contents.map.with_index { |source, index| write_service_file(dir, index, source) }
      end

      def write_service_file(dir, index, source)
        File.join(dir, "workflow_#{index}.rb").tap { |path| File.write(path, source) }
      end

      def fake_index(files, available: true)
        FakeServiceIndex.new(available: available, indexed_files: files)
      end

      def service_soup_fixture_path
        File.expand_path("../../fixtures/service_soup_app", __dir__)
      end

      def service_soup_fixture_controller
        File.join(service_soup_fixture_path, "app/controllers/orders_controller.rb")
      end
    end

    class ServiceSoupPerformTest < Minitest::Test
      include ServiceSoupFixtureSources

      def test_reports_namespaced_perform_service_workflow
        with_service_files([perform_service_source]) do |files|
          assert_perform_service_finding(ServiceSoup.new(index: fake_index(files)).call.first)
        end
      end

      private

      def assert_perform_service_finding(finding)
        assert_equal "Inboxes::FetchImapEmailsJob#process_email_for_channel", finding.workflow
        assert_equal expected_services, finding.services
        assert_equal %i[new_perform], finding.occurrences.map(&:style).uniq
      end

      def expected_services
        %w[Imap::FetchEmailService Imap::GoogleFetchEmailService Imap::MicrosoftFetchEmailService]
      end

      def with_service_files(contents)
        Dir.mktmpdir { |dir| yield contents.map.with_index { |source, index| write_file(dir, index, source) } }
      end

      def write_file(dir, index, source)
        File.join(dir, "workflow_#{index}.rb").tap { |path| File.write(path, source) }
      end

      def fake_index(files)
        FakeServiceIndex.new(available: true, indexed_files: files)
      end
    end

    class ServiceSoupRubydexTest < Minitest::Test
      include ServiceSoupFixtureSources

      def test_reports_service_soup_from_project_index
        skip "rubydex is not installed" unless ProjectIndex::RubydexBackend.available?

        with_rubydex_fixture do |index|
          finding = ServiceSoup.new(index: index).call.first

          assert_equal "OrdersController#create", finding.workflow
        end
      end

      private

      def with_rubydex_fixture
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "workflow.rb"), service_soup_source)
          yield ProjectIndex.build([dir], backend: :rubydex)
        end
      end
    end

    class FakeServiceIndex
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
