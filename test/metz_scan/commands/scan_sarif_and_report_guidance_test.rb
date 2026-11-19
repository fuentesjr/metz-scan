# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    module ScanSarifAndReportGuidanceFixtures
      STOCK_SOURCE = <<~RUBY
        # frozen_string_literal: true
        answer=1
      RUBY

      STOCK_CONFIG = <<~YAML
        AllCops:
          NewCops: disable
        Layout/SpaceAroundOperators:
          Description: Project-specific operator spacing guidance.
      YAML

      LONG_METHOD_SOURCE = <<~RUBY
        # frozen_string_literal: true
        def long_method
          a = 1
          b = 2
          c = 3
          d = 4
          e = 5
          [a, b, c, d, e]
        end
      RUBY

      STOCK_DESCRIPTION = "Project-specific operator spacing guidance."
      METHODS_TOO_LONG_WHY =
        "Long methods hide multiple responsibilities and resist understanding at a glance."
    end

    module ScanSarifAndReportGuidanceSupport
      include ScanSarifAndReportGuidanceFixtures

      def setup
        @project = File.realpath(Dir.mktmpdir("metz-scan-sarif-report-guidance"))
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      private

      def write_file(path, content)
        File.write(File.join(@project, path), content)
      end

      def metz_scan(*args, expected_exit:)
        run_subprocess([RbConfig.ruby, File.join(repo_root, "bin/metz-scan"), *args], expected_exit:)
      end

      def raw_rubocop_json
        run_subprocess(
          [RbConfig.ruby, "-S", "rubocop", "--plugin", "rubocop-metz", "--force-default-config",
           "--only", "Metz/MethodsTooLong", "--format", "json", "long.rb"],
          expected_exit: 1
        )
      end

      def run_subprocess(command_args, expected_exit:)
        stdout, stderr, status = Open3.capture3(subprocess_env, "bundle", "exec", *command_args, chdir: @project)
        assert_equal expected_exit, status.exitstatus, "#{command_args.join(' ')} failed: #{stderr}\n#{stdout}"
        stdout
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def repo_root = File.expand_path("../../..", __dir__)

      def sarif_rule(sarif_doc, cop_name)
        rules = sarif_doc.dig("runs", 0, "tool", "driver", "rules")
        rule = rules.find { |entry| entry.fetch("id") == cop_name }
        refute_nil rule, "Expected SARIF rules to include #{cop_name}"
        rule
      end

      def write_raw_rubocop_report
        write_file("long.rb", LONG_METHOD_SOURCE)
        raw_json = raw_rubocop_json
        assert_raw_rubocop_shape(JSON.parse(raw_json))
        write_file("raw.json", raw_json)
      end

      def assert_raw_rubocop_shape(raw_doc)
        refute raw_doc.key?("guidance"), "Raw RuboCop JSON must not contain a guidance map"
        offense = raw_doc.dig("files", 0, "offenses", 0)
        assert_equal "Metz/MethodsTooLong", offense.fetch("cop_name")
        refute offense.key?("why_it_matters"), "Raw RuboCop JSON offense must not contain why_it_matters"
      end

      def assert_rule_text(rule, expected_text)
        refute_empty expected_text
        assert_equal({ "text" => expected_text }, rule["help"])
        assert_equal({ "text" => expected_text }, rule["fullDescription"])
      end
    end

    class ScanSarifAndReportGuidanceTest < Minitest::Test
      include ScanSarifAndReportGuidanceSupport

      def test_all_cops_live_sarif_includes_stock_descriptions_and_matches_report
        write_file("stock.rb", STOCK_SOURCE)
        write_file(".rubocop.yml", STOCK_CONFIG)
        live_sarif = JSON.parse(metz_scan("scan", ".", "--all-cops", "--format", "sarif", expected_exit: 1))
        assert_equal report_sarif_from_all_cops_json, live_sarif
        assert_rule_text(sarif_rule(live_sarif, "Layout/SpaceAroundOperators"), STOCK_DESCRIPTION)
      end

      def test_default_scan_sarif_omits_stock_guidance_for_lint_syntax
        write_file("broken.rb", "def broken(\n")
        sarif = JSON.parse(metz_scan("scan", ".", "--format", "sarif", expected_exit: 1))
        rule = sarif_rule(sarif, "Lint/Syntax")
        refute rule.key?("help")
        refute rule.key?("fullDescription")
      end

      def test_report_sarif_on_raw_rubocop_json_includes_metz_why_it_matters
        write_raw_rubocop_report
        sarif = JSON.parse(metz_scan("report", "raw.json", "--format", "sarif", expected_exit: 1))
        rule = sarif_rule(sarif, "Metz/MethodsTooLong")
        assert_rule_text(rule, METHODS_TOO_LONG_WHY)
      end

      def test_report_text_on_raw_rubocop_json_includes_metz_why_it_matters
        write_raw_rubocop_report
        text = metz_scan("report", "raw.json", "--format", "text", expected_exit: 1)
        assert_includes text, "  Why it matters: #{METHODS_TOO_LONG_WHY}\n"
        assert_includes text, "  Run `metz-scan explain Metz/MethodsTooLong` for details.\n"
      end

      private

      def report_sarif_from_all_cops_json
        write_file("saved.json", metz_scan("scan", ".", "--all-cops", "--format", "json", expected_exit: 1))
        JSON.parse(metz_scan("report", "saved.json", "--format", "sarif", expected_exit: 1))
      end
    end
  end
end
