# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  class CheckRubydexDriftTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    SAMPLE_APP_PATH = "test/fixtures/sample_app"
    MISSING_RUBYDEX_MESSAGE =
      "check_rubydex_drift: rubydex is unavailable; enable the optional rubydex bundle group first"

    def test_help_documents_compatibility_no_write_option
      stdout, stderr, status = capture_command("--help")

      assert_predicate status, :success?, stderr
      assert_includes stdout, "check_rubydex_drift"
      assert_includes stdout, "--no-write"
    end

    def test_text_output_is_compact_for_sample_app
      skip "rubydex is unavailable" unless rubydex_available?

      stdout, stderr, status = capture_command("--text", SAMPLE_APP_PATH)

      assert_predicate status, :success?, stderr
      assert_equal fixture("sample_app_text.txt"), stdout
      assert_no_noisy_sections(stdout)
    end

    def test_fails_clearly_when_rubydex_is_missing
      stdout, stderr, status = capture_command_with_missing_rubydex("--text", SAMPLE_APP_PATH)

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes stderr, MISSING_RUBYDEX_MESSAGE
      refute_includes stdout, "rubydex drift check"
    end

    def test_allow_missing_rubydex_skips_when_rubydex_is_missing
      stdout, stderr, status = capture_command_with_missing_rubydex(*allow_missing_rubydex_args)

      assert_missing_rubydex_skip(stdout, stderr, status)
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

    def assert_no_noisy_sections(stdout)
      refute_includes stdout, "notable findings:"
      refute_includes stdout, "artifacts:"
    end

    def assert_missing_rubydex_skip(stdout, stderr, status)
      assert_predicate status, :success?, stderr
      assert_empty stderr
      assert_equal "#{MISSING_RUBYDEX_MESSAGE}; skipped\n", stdout
      refute_includes stdout, "rubydex drift check"
    end

    def allow_missing_rubydex_args
      ["--allow-missing-rubydex", "--text", SAMPLE_APP_PATH]
    end

    def capture_command(*args)
      env = args.first.is_a?(Hash) ? args.shift : {}
      Open3.capture3(env, check_rubydex_drift_path, *args, chdir: REPO_ROOT)
    end

    def capture_command_with_missing_rubydex(*args)
      Dir.mktmpdir("metz-scan-missing-rubydex") do |dir|
        shim = File.join(dir, "missing_rubydex.rb")
        File.write(shim, missing_rubydex_shim)
        capture_command({ "RUBYOPT" => "-r#{shim}" }, *args)
      end
    end

    def missing_rubydex_shim
      <<~RUBY
        module Kernel
          alias_method :metz_scan_original_require, :require

          def require(feature)
            raise LoadError, "cannot load such file -- rubydex" if feature == "rubydex"

            metz_scan_original_require(feature)
          end
        end
      RUBY
    end

    def rubydex_available?
      system(RbConfig.ruby, "-e", "require 'rubydex'", out: File::NULL, err: File::NULL)
    end

    def fixture(name)
      File.read(File.join(REPO_ROOT, "test/fixtures/check_rubydex_drift", name))
    end

    def check_rubydex_drift_path = File.join(REPO_ROOT, "bin/check_rubydex_drift")
  end
end
