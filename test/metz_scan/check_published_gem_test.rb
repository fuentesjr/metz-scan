# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  CheckPublishedGemResult = Struct.new(:stdout, :stderr, :status, :log, keyword_init: true) do
    def success? = status.success?
  end
  CHECK_PUBLISHED_GEM_SECRET_TOKEN = "token-for-check-published-gem-test"
  CHECK_PUBLISHED_GEM_POLLUTED_ENV = {
    "BUNDLE_GEMFILE" => "/tmp/contaminated/Gemfile",
    "BUNDLE_BIN_PATH" => "/tmp/contaminated-bundle-bin",
    "BUNDLE_APP_CONFIG" => "/tmp/contaminated-bundle-app-config",
    "BUNDLE_PATH" => "/tmp/contaminated-bundle-path",
    "BUNDLER_VERSION" => "9.9.9",
    "GEM_HOME" => "/tmp/contaminated-gem-home",
    "GEM_PATH" => "/tmp/contaminated-gem-path",
    "RUBYLIB" => "/tmp/contaminated-rubylib",
    "RUBYOPT" => "-v",
    "BUNDLE_RUBYGEMS__PKG__GITHUB__COM" => "fuentesjr:#{CHECK_PUBLISHED_GEM_SECRET_TOKEN}",
    "GITHUB_PACKAGES_TOKEN" => CHECK_PUBLISHED_GEM_SECRET_TOKEN,
    "GEM_CREDENTIALS" => "/tmp/contaminated-credentials"
  }.freeze

  class CheckPublishedGemTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    VERSION = "9.8.7"

    def test_published_gem_smoke_is_local_isolated_and_redacted
      with_smoke_result { |result, tmp_base| assert_successful_smoke(result, tmp_base) }
    end

    def test_published_gem_smoke_scopes_ambient_bundler_credential
      with_smoke_result(
        bundler_credential: true,
        ambient_env: CHECK_PUBLISHED_GEM_POLLUTED_ENV
      ) { |result, tmp_base| assert_successful_smoke(result, tmp_base) }
    end

    def test_published_gem_smoke_uses_gem_credentials_fallback
      with_smoke_result(gem_credentials: true) { |result, tmp_base| assert_successful_smoke(result, tmp_base) }
    end

    def test_rejects_temp_base_inside_repository
      with_repo_tmp_base_result { |result, log_path| assert_rejects_repo_tmp_base(result, log_path) }
    end

    def test_release_checklists_run_published_gem_smoke_after_publish
      [File.join(REPO_ROOT, "RELEASE_CHECKLIST.md"),
       File.join(REPO_ROOT, ".github/ISSUE_TEMPLATE/release_checklist.md")].each do |path|
        checklist = File.read(path)

        assert_includes checklist, "bin/check_published_gem X.Y.Z", path
      end
    end
  end

  module CheckPublishedGemSmokeHelpers
    private

    def with_smoke_result(options = {})
      with_fake_bundle do |fake_dir|
        Dir.mktmpdir("metz-scan-published-gem-smoke") do |tmp_base|
          yield run_check_published_gem(tmp_base, fake_dir, options), tmp_base
        end
      end
    end

    def run_check_published_gem(tmp_base, fake_dir, options = {})
      log_path = bundle_log(fake_dir)
      stdout, stderr, status = capture_check_published_gem(tmp_base, fake_bundle(fake_dir), options)

      CheckPublishedGemResult.new(stdout: stdout, stderr: stderr, status: status, log: log_for(log_path))
    end

    def capture_check_published_gem(tmp_base, fake_bundle_path, options)
      Open3.capture3(env_for(tmp_base, fake_bundle_path, options), check_published_gem_path, self.class::VERSION)
    end

    def env_for(tmp_base, fake_bundle_path, options)
      base_env.merge("BUNDLE_BIN" => fake_bundle_path, "HOME" => File.join(tmp_base, "home"),
                     "PUBLISHED_GEM_SMOKE_TMPDIR" => tmp_base)
              .merge(options.fetch(:ambient_env, {}))
              .merge(credential_env(tmp_base, options))
    end

    def assert_successful_smoke(result, tmp_base)
      assert result.success?, result.stderr
      assert_redacted(result)
      assert_exact_gem_pin(result.log)
      assert_external_temp_project(result.log, tmp_base)
    end

    def assert_rejects_repo_tmp_base(result, log_path)
      refute result.success?
      assert_empty result.stdout
      assert_includes result.stderr, "temp base must be outside this repository"
      refute_path_exists log_path
    end

    def assert_redacted(result)
      assert_includes result.stdout, "[REDACTED]"
      assert_includes result.stderr, "[REDACTED]"
      refute_includes "#{result.stdout}\n#{result.stderr}", CHECK_PUBLISHED_GEM_SECRET_TOKEN
    end

    def assert_exact_gem_pin(log)
      assert_includes log, %(gem_line=gem "metz-scan", "#{self.class::VERSION}")
    end

    def assert_external_temp_project(log, tmp_base)
      install_pwd = log[/^install_pwd=(.+)$/, 1]

      refute_nil install_pwd
      assert_match(/\A#{Regexp.escape("#{File.realpath(tmp_base)}/")}/, install_pwd)
      refute_match(/\A#{Regexp.escape("#{File.realpath(self.class::REPO_ROOT)}/")}/, install_pwd)
      refute_path_exists install_pwd
    end

    def base_env
      { "BUNDLE_RUBYGEMS__PKG__GITHUB__COM" => nil, "PATH" => ENV.fetch("PATH"),
        "GEM_CREDENTIALS" => nil, "GITHUB_PACKAGES_TOKEN" => nil, "RUBY_BIN" => RbConfig.ruby }
    end

    def credential_env(tmp_base, options)
      return { "GEM_CREDENTIALS" => write_gem_credentials(tmp_base) } if options.fetch(:gem_credentials, false)

      credential_env_from_token(options.fetch(:bundler_credential, false))
    end

    def credential_env_from_token(bundler_credential)
      { credential_key(bundler_credential) => credential_value(bundler_credential) }
    end

    def credential_key(bundler_credential)
      bundler_credential ? "BUNDLE_RUBYGEMS__PKG__GITHUB__COM" : "GITHUB_PACKAGES_TOKEN"
    end

    def credential_value(bundler_credential)
      bundler_credential ? "fuentesjr:#{CHECK_PUBLISHED_GEM_SECRET_TOKEN}" : CHECK_PUBLISHED_GEM_SECRET_TOKEN
    end

    def write_gem_credentials(tmp_base)
      File.join(tmp_base, "credentials.yml").tap do |path|
        File.write(path, "---\n:github: Bearer #{CHECK_PUBLISHED_GEM_SECRET_TOKEN}\n")
        File.chmod(0o600, path)
      end
    end

    def with_fake_bundle(&)
      Dir.mktmpdir("metz-scan-fake-bundle", &)
    end

    def fake_bundle_fixture_path
      File.join(self.class::REPO_ROOT, "test/fixtures/check_published_gem/fake_bundle")
    end

    def check_published_gem_path = File.join(self.class::REPO_ROOT, "bin/check_published_gem")

    def bundle_log(fake_dir) = File.join(fake_dir, "bundle.log")

    def log_for(log_path) = File.exist?(log_path) ? File.read(log_path) : ""

    def with_repo_tmp_base_result
      with_fake_bundle do |fake_dir|
        yield run_check_published_gem(self.class::REPO_ROOT, fake_dir), bundle_log(fake_dir)
      end
    end

    def fake_bundle(fake_dir)
      File.join(fake_dir, "bundle").tap do |path|
        FileUtils.cp(fake_bundle_fixture_path, path)
        File.chmod(0o755, path)
      end
    end
  end

  class CheckPublishedGemTest
    include CheckPublishedGemSmokeHelpers
  end
end
