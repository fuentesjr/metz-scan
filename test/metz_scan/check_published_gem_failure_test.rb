# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  CheckPublishedGemFailureResult = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
    def success? = status.success?
  end

  class CheckPublishedGemFailureTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    VERSION = "9.8.7"
    SECRET_TOKEN = "token-for-check-published-gem-failure-test"

    def test_missing_credentials_reports_troubleshooting_steps
      assert_missing_credential_failure(run_smoke(credential: false))
    end

    def test_bundle_install_failure_reports_actionable_hint
      assert_bundle_install_failure(run_smoke(fail_install: true))
    end

    private

    def run_smoke(options)
      with_fake_bundle do |fake_dir|
        with_tmp_base { |tmp_base| run_check(tmp_base, prepared_bundle(fake_dir, options), options) }
      end
    end

    def run_check(tmp_base, fake_bundle_path, options)
      stdout, stderr, status = Open3.capture3(env_for(tmp_base, fake_bundle_path, options), check_path, VERSION)
      CheckPublishedGemFailureResult.new(stdout: stdout, stderr: stderr, status: status)
    end

    def env_for(tmp_base, fake_bundle_path, options)
      env = base_env(tmp_base, fake_bundle_path)
      options.fetch(:credential, true) ? env.merge("GITHUB_PACKAGES_TOKEN" => SECRET_TOKEN) : env
    end

    def base_env(tmp_base, fake_bundle_path)
      { "BUNDLE_BIN" => fake_bundle_path, "BUNDLE_RUBYGEMS__PKG__GITHUB__COM" => nil,
        "GEM_CREDENTIALS" => nil, "GITHUB_PACKAGES_TOKEN" => nil, "HOME" => File.join(tmp_base, "home"),
        "PATH" => ENV.fetch("PATH"), "PUBLISHED_GEM_SMOKE_TMPDIR" => tmp_base, "RUBY_BIN" => RbConfig.ruby }
    end

    def prepared_bundle(fake_dir, options)
      write_fail_install_marker(fake_dir) if options.fetch(:fail_install, false)
      fake_bundle(fake_dir)
    end

    def assert_missing_credential_failure(result)
      refute result.success?
      assert_empty result.stdout
      assert_failure_hints(result.stderr, "missing GitHub Packages credentials")
    end

    def assert_bundle_install_failure(result)
      refute result.success?
      assert_redacted(result)
      assert_failure_hints(result.stderr, "bundle install failed")
    end

    def assert_failure_hints(stderr, message)
      assert_includes stderr, message
      assert_includes stderr, "read:packages"
      assert_includes stderr, "GITHUB_PACKAGES_TOKEN"
    end

    def assert_redacted(result)
      assert_includes result.stdout, "[REDACTED]"
      assert_includes result.stderr, "[REDACTED]"
      refute_includes "#{result.stdout}\n#{result.stderr}", SECRET_TOKEN
    end

    def with_fake_bundle(&)
      Dir.mktmpdir("metz-scan-fake-bundle", &)
    end

    def with_tmp_base(&)
      Dir.mktmpdir("metz-scan-published-gem-smoke", &)
    end

    def fake_bundle(fake_dir)
      File.join(fake_dir, "bundle").tap { |path| copy_fake_bundle(path) }
    end

    def copy_fake_bundle(path)
      FileUtils.cp(fake_bundle_fixture_path, path)
      File.chmod(0o755, path)
    end

    def write_fail_install_marker(fake_dir)
      File.write(File.join(fake_dir, "fail_install"), "1")
    end

    def fake_bundle_fixture_path
      File.join(REPO_ROOT, "test/fixtures/check_published_gem/fake_bundle")
    end

    def check_path = File.join(REPO_ROOT, "bin/check_published_gem")
  end
end
