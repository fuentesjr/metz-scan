# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    class ScanStockGuidanceScopeTest < Minitest::Test
      NO_GUIDANCE = { "why_it_matters" => "", "suggested_next_moves" => [], "fix_safety" => "" }.freeze
      SYNTAX_ERROR_SOURCE = "def broken(\n"
      BROKEN_CONFIG = "require: rubocop-does-not-exist\n"
      AUTOCORRECT_DISABLED_CONFIG = <<~YAML
        AllCops:
          NewCops: disable
        Style/StringLiterals:
          AutoCorrect: false
      YAML

      def setup
        @project = File.realpath(Dir.mktmpdir("metz-scan-stock-guidance-scope"))
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      def test_default_scan_gives_stock_syntax_offenses_empty_guidance
        write_file("broken.rb", SYNTAX_ERROR_SOURCE)

        assert_default_syntax_output
      end

      def test_default_scan_ignores_a_broken_project_config_for_stock_guidance
        write_file("broken.rb", SYNTAX_ERROR_SOURCE)
        write_file(".rubocop.yml", BROKEN_CONFIG)

        assert_default_syntax_output
      end

      def test_all_cops_guidance_marks_stock_cops_with_autocorrect_disabled_as_manual
        write_file("stock.rb", "# frozen_string_literal: true\n\nputs \"hello\"\n")
        write_file(".rubocop.yml", AUTOCORRECT_DISABLED_CONFIG)
        guidance = JSON.parse(scan("json", "--all-cops")).fetch("guidance")

        assert_equal "manual", guidance.fetch("Style/StringLiterals").fetch("fix_safety")
      end

      private

      def assert_default_syntax_output
        assert_equal NO_GUIDANCE, JSON.parse(scan("json")).fetch("guidance").fetch("Lint/Syntax")
        text = scan("text")
        assert_includes text, "Lint/Syntax\n"
        refute_includes text, "Why it matters"
      end

      def write_file(path, source)
        File.write(File.join(@project, path), source)
      end

      def scan(format, *flags)
        stdout, stderr, status = Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby,
                                                File.join(repo_root, "bin/metz-scan"), "scan", ".", *flags,
                                                "--format", format, chdir: @project)
        assert_equal 1, status.exitstatus, "scan --format #{format} failed: #{stderr}\n#{stdout}"
        stdout
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def repo_root = File.expand_path("../../..", __dir__)
    end
  end
end
