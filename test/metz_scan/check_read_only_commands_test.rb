# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  class CheckReadOnlyCommandsTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    GuardResult = Struct.new(:stdout, :stderr, :status, keyword_init: true)

    def test_passes_when_command_leaves_tracked_files_unchanged
      with_git_repo do |dir|
        result = run_guard(dir, "#{RbConfig.ruby} -e 'puts :ok'")

        assert_predicate result.status, :success?, result.stderr
        assert_includes result.stdout, "check_read_only_commands: ok"
      end
    end

    def test_fails_when_command_changes_tracked_files
      with_git_repo do |dir|
        result = run_guard(dir, "#{RbConfig.ruby} -e 'File.write(\"tracked.txt\", \"changed\")'")

        assert_mutation_failure(result)
      end
    end

    private

    def assert_mutation_failure(result)
      refute_predicate result.status, :success?
      assert_includes result.stderr, "changed tracked files"
      assert_includes result.stderr, "tracked.txt"
    end

    def run_guard(dir, command)
      stdout, stderr, status = Open3.capture3(check_read_only_commands_path, "--command", command, chdir: dir)
      GuardResult.new(stdout: stdout, stderr: stderr, status: status)
    end

    def with_git_repo
      Dir.mktmpdir("metz-scan-read-only-guard") do |dir|
        initialize_git_repo(dir)
        yield dir
      end
    end

    def initialize_git_repo(dir)
      File.write(File.join(dir, "tracked.txt"), "original")
      git(dir, "init")
      git(dir, "add", "tracked.txt")
      git(dir, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "initial")
    end

    def git(dir, *args)
      system("git", *args, chdir: dir, out: File::NULL, err: File::NULL) || flunk("git #{args.join(' ')} failed")
    end

    def check_read_only_commands_path = File.join(REPO_ROOT, "bin/check_read_only_commands")
  end
end
