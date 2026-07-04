# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  class CheckRubydexDriftTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_help_documents_compatibility_no_write_option
      stdout, stderr, status = capture_command("--help")

      assert_predicate status, :success?, stderr
      assert_includes stdout, "check_rubydex_drift"
      assert_includes stdout, "--no-write"
    end

    def test_text_output_is_compact_for_sample_app
      skip "rubydex is unavailable" unless rubydex_available?

      stdout, stderr, status = capture_command("--text", "test/fixtures/sample_app")

      assert_compact_text_output(stdout, stderr, status)
    end

    def test_json_analyzers_match_project_runner_index_backed_analyzers
      skip "rubydex is unavailable" unless rubydex_available?

      stdout, stderr, status = capture_command("--json", "test/fixtures/sample_app")

      assert_predicate status, :success?, stderr
      assert_equal index_backed_rule_ids, JSON.parse(stdout).fetch("analyzers")
    end

    private

    def index_backed_rule_ids
      Commands::Scan::ProjectAnalyzerRunner::INDEX_BACKED_ANALYZERS.map { |analyzer| analyzer::RULE_ID }
    end

    def assert_compact_text_output(stdout, stderr, status)
      assert_predicate status, :success?, stderr
      assert_includes stdout, "rubydex drift check"
      assert_includes stdout, "MetzProject/DeepInheritanceTree"
      assert_includes stdout, "findings:"
      assert_no_noisy_sections(stdout)
    end

    def assert_no_noisy_sections(stdout)
      refute_includes stdout, "notable findings:"
      refute_includes stdout, "artifacts:"
    end

    def capture_command(*)
      Open3.capture3(check_rubydex_drift_path, *, chdir: REPO_ROOT)
    end

    def rubydex_available?
      system(RbConfig.ruby, "-e", "require 'rubydex'", out: File::NULL, err: File::NULL)
    end

    def check_rubydex_drift_path = File.join(REPO_ROOT, "bin/check_rubydex_drift")
  end
end
