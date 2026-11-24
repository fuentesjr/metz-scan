# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require "metz_scan/analyzers/repeated_branching"
require "metz_scan/analyzers/service_soup"
require "metz_scan/analyzers/source_cache"
require "metz_scan/commands/scan/project_config_scope"

module MetzScan
  module Analyzers
    class SourceCacheTest < Minitest::Test
      SAMPLE_SOURCE = <<~RUBY
        class OrdersController
          def create(order)
            case order.status
            when "pending" then ValidateOrder.call(order)
            when "paid" then ReserveInventory.call(order)
            end
            CapturePayment.new(order).call
          end
        end
      RUBY

      def test_caches_ast_and_contextual_nodes_inside_with_block
        with_ruby_file(SAMPLE_SOURCE) do |path|
          SourceCache.with do
            first_ast = SourceCache.ast(path)
            first_nodes = SourceCache.contextual_nodes(path)
            File.write(path, "class Replaced; end\n")

            assert_same first_ast, SourceCache.ast(path)
            assert_same first_nodes, SourceCache.contextual_nodes(path)
          end
          assert_nil SourceCache.current
        end
      end

      def test_shares_single_parse_across_analyzers
        with_ruby_file(SAMPLE_SOURCE) do |path|
          SourceCache.with do
            RepeatedBranching.new(paths: [path]).call
            File.write(path, "class Empty; end\n")

            findings = ServiceSoup.new(paths: [path]).call
            assert_equal 1, findings.size
          end
        end
      end

      def test_handles_nonexistent_and_syntax_error_files_safely
        with_ruby_file("class (\n") do |broken_path|
          missing_path = File.join(File.dirname(broken_path), "missing.rb")
          SourceCache.with { assert_safe_fallbacks(missing_path, broken_path) }
        end
      end

      def test_works_standalone_outside_with_block
        with_ruby_file(SAMPLE_SOURCE) do |path|
          assert_nil SourceCache.current
          refute_nil SourceCache.ast(path)
          refute_empty SourceCache.contextual_nodes(path)
        end
      end

      def test_raises_on_unsupported_ruby_version_instead_of_swallowing_argument_error
        with_ruby_file(SAMPLE_SOURCE) do |path|
          assert_raises(ArgumentError) do
            SourceCache.with(ruby_version: 99.0) { SourceCache.ast(path) }
          end
        end
      end

      def test_resolves_target_ruby_version_per_file_from_config_store
        Dir.mktmpdir do |dir|
          legacy_dir = File.join(dir, "legacy").tap { |d| Dir.mkdir(d) }
          modern_dir = File.join(dir, "modern").tap { |d| Dir.mkdir(d) }
          File.write(File.join(legacy_dir, ".rubocop.yml"), "AllCops:\n  TargetRubyVersion: 3.0\n")
          File.write(File.join(modern_dir, ".rubocop.yml"), "AllCops:\n  TargetRubyVersion: 3.3\n")
          legacy_file = File.join(legacy_dir, "anon.rb").tap { |f| File.write(f, "def f(&) = g(&)\n") }
          modern_file = File.join(modern_dir, "anon.rb").tap { |f| File.write(f, "def f(&) = g(&)\n") }
          store = Commands::Scan::ProjectConfigScope.store

          SourceCache.with(config_store: store) do
            assert_nil SourceCache.ast(legacy_file)
            refute_nil SourceCache.ast(modern_file)
          end
        end
      end

      def test_skips_invalid_utf8_files_without_raising
        Dir.mktmpdir do |dir|
          binary_path = File.join(dir, "bad.rb")
          File.binwrite(binary_path, "x = \"\xFF\xFE\"\n")

          SourceCache.with do
            assert_nil SourceCache.ast(binary_path)
            assert_empty SourceCache.contextual_nodes(binary_path)
          end
        end
      end

      private

      def assert_safe_fallbacks(missing_path, broken_path)
        assert_nil SourceCache.ast(missing_path)
        assert_empty SourceCache.contextual_nodes(missing_path)
        assert_nil SourceCache.ast(broken_path)
        assert_empty SourceCache.contextual_nodes(broken_path)
      end

      def with_ruby_file(source)
        Dir.mktmpdir do |dir|
          path = File.join(dir, "sample.rb")
          File.write(path, source)
          yield path
        end
      end
    end
  end
end
