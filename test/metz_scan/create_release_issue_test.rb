# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  class CreateReleaseIssueTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_dry_run_renders_release_issue_without_gh
      with_minimal_path { |env| assert_dry_run_issue(capture_release_issue(env, "--dry-run")) }
    end

    def test_real_issue_creation_requires_gh
      with_minimal_path { |env| assert_requires_gh(capture_release_issue(env)) }
    end

    private

    def assert_dry_run_issue(result)
      stdout, stderr, status = result

      assert_predicate status, :success?, stderr
      assert_empty stderr
      assert_dry_run_title_and_versions(stdout)
      assert_includes stdout, "## Verification"
    end

    def assert_dry_run_title_and_versions(stdout)
      assert_includes stdout, "# Release v0.5.2"
      assert_includes stdout, "- `metz-scan`: `0.5.2`"
      assert_includes stdout, "- `rubocop-metz`: `0.5.2`"
    end

    def assert_requires_gh(result)
      stdout, stderr, status = result

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes stderr, "gh CLI is required"
    end

    def capture_release_issue(env, *)
      Open3.capture3(env, create_release_issue_path, *)
    end

    def with_minimal_path
      Dir.mktmpdir("metz-scan-create-release-issue-path") do |dir|
        build_minimal_bin(dir)
        yield({ "PATH" => dir })
      end
    end

    def build_minimal_bin(dir)
      command_paths.each { |name, path| FileUtils.ln_s(path, File.join(dir, name)) }
    end

    def command_paths
      { "bash" => command_path("bash"), "dirname" => command_path("dirname"),
        "mktemp" => command_path("mktemp"), "awk" => command_path("awk"),
        "cat" => command_path("cat"), "rm" => command_path("rm"),
        "ruby" => RbConfig.ruby }
    end

    def command_path(name)
      ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }.find { |path| File.executable?(path) }
    end

    def create_release_issue_path
      File.join(REPO_ROOT, "bin/create_release_issue")
    end
  end
end
