# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

module MetzScan
  module CheckCiParityRepoFixture
    REPO_ROOT = File.expand_path("../..", __dir__)
    RepoPaths = Struct.new(:repo, :fake_bin, :tmp_base, :bundle_log, keyword_init: true)
    GUARD_STUBS = %w[check_dependency_direction check_read_only_commands check_sample_app_frozen].freeze
    FAKE_BUNDLE_SOURCE = <<~RUBY
      #!/usr/bin/env ruby
      File.open(ENV.fetch("FAKE_BUNDLE_LOG"), "a") { |file| file.puts(ARGV.join(" ")) }
      if %<fail_rubocop>s && ARGV == ["exec", "rubocop"]
        warn "fake rubocop failed"
        exit 42
      end
    RUBY

    def with_ci_parity_repo(tracker:, fail_rubocop: false)
      Dir.mktmpdir("metz-scan-ci-parity-test") do |dir|
        yield prepared_ci_parity_repo(dir, tracker, fail_rubocop)
      end
    end

    def prepared_ci_parity_repo(dir, tracker, fail_rubocop)
      paths = ci_parity_paths(dir)
      build_ci_repo(paths, tracker, fail_rubocop)
      paths
    end

    def build_ci_repo(paths, tracker, fail_rubocop)
      FileUtils.mkdir_p([paths.repo, paths.fake_bin, paths.tmp_base])
      build_repo(paths.repo, tracker)
      build_fake_bundle(paths.fake_bin, fail_rubocop)
      initialize_git(paths.repo)
    end

    def ci_parity_paths(dir)
      RepoPaths.new(repo: File.join(dir, "repo"), fake_bin: File.join(dir, "fake-bin"),
                    tmp_base: File.join(dir, "tmp"), bundle_log: File.join(dir, "bundle.log"))
    end

    def build_repo(repo, tracker)
      FileUtils.mkdir_p(File.join(repo, "bin"))
      copy_ci_scripts(repo)
      write_guard_stubs(repo)
      File.write(File.join(repo, "PROJECT_TRACKER.md"), tracker)
    end

    def copy_ci_scripts(repo)
      copy_script(repo, "check_ci_parity")
      copy_script(repo, "check_tracker_queue")
    end

    def write_guard_stubs(repo)
      GUARD_STUBS.each { |name| write_stub(repo, name) }
      write_executable(File.join(repo, "bin/check_project_analyzer_calibration"), "#!/usr/bin/env ruby\nexit 0\n")
    end

    def write_stub(repo, name)
      write_executable(File.join(repo, "bin", name), "#!/usr/bin/env ruby\nputs '#{name}: ok'\n")
    end

    def copy_script(repo, name)
      target = File.join(repo, "bin", name)
      FileUtils.cp(File.join(REPO_ROOT, "bin", name), target)
      File.chmod(0o755, target)
    end

    def build_fake_bundle(fake_bin, fail_rubocop)
      write_executable(File.join(fake_bin, "bundle"), format(FAKE_BUNDLE_SOURCE, fail_rubocop: fail_rubocop.inspect))
    end

    def write_executable(path, contents)
      File.write(path, contents)
      File.chmod(0o755, path)
    end

    def initialize_git(repo)
      git(repo, "init")
      git(repo, "add", ".")
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "initial")
    end

    def git(repo, *args)
      system("git", *args, chdir: repo, out: File::NULL, err: File::NULL) || flunk("git #{args.join(' ')} failed")
    end

    def watch_only_tracker
      tracker_with_items("Continue package feedback watch.", "Keep #25 deferred.", "Monitor analyzer evidence.")
    end

    def actionable_tracker
      tracker_with_items("Improve parity diagnostics.", "Keep #25 deferred.", "Monitor analyzer evidence.")
    end

    def tracker_with_items(*items)
      body = items.each_with_index.map { |item, index| "#{index + 1}. #{item}" }.join("\n")
      "# Project Tracker\n\n## Next Queue\n\n#{body}\n"
    end
  end

  module CheckCiParityHelpers
    include CheckCiParityRepoFixture

    Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

    def assert_tracker_queue_failure(paths)
      result = run_ci_parity(paths)
      refute_predicate result.status, :success?
      assert_includes result.stderr, "check_tracker_queue"
      refute_path_exists paths.bundle_log
    end

    def assert_phase_failure(paths)
      result = run_ci_parity(paths)
      assert_failed_phase_status(result)
      assert_phase_stderr(result.stderr)
      assert_path_exists preserved_clone_path(result.stderr)
    end

    def assert_successful_cleanup(paths)
      result = run_ci_parity(paths)
      assert_predicate result.status, :success?, result.stderr
      assert_includes result.stdout, "phase=bundle install ok"
      assert_empty Dir.children(paths.tmp_base)
    end

    def assert_failed_phase_status(result)
      refute_predicate result.status, :success?
    end

    def assert_phase_stderr(stderr)
      assert_includes stderr, "failed phase"
      assert_includes stderr, "rubocop"
      assert_includes stderr, "clean clone preserved at"
      assert_includes stderr, "next action: cd #{preserved_clone_path(stderr)} && bundle exec rubocop"
    end

    def run_ci_parity(paths)
      stdout, stderr, status = Open3.capture3(ci_env(paths), File.join(paths.repo, "bin/check_ci_parity"),
                                              chdir: paths.repo)
      Result.new(stdout: stdout, stderr: stderr, status: status)
    end

    def ci_env(paths)
      { "PATH" => "#{paths.fake_bin}:#{ENV.fetch('PATH')}", "CI_PARITY_TMPDIR" => paths.tmp_base,
        "FAKE_BUNDLE_LOG" => paths.bundle_log }
    end

    def preserved_clone_path(stderr)
      stderr[/clean clone preserved at (.+)$/, 1].to_s.strip
    end
  end

  class CheckCiParityTest < Minitest::Test
    include CheckCiParityHelpers

    def test_runs_tracker_queue_before_bundler
      with_ci_parity_repo(tracker: watch_only_tracker) { |paths| assert_tracker_queue_failure(paths) }
    end

    def test_failure_output_names_phase_and_preserves_clean_clone
      with_ci_parity_repo(tracker: actionable_tracker, fail_rubocop: true) { |paths| assert_phase_failure(paths) }
    end

    def test_success_output_names_phase_and_removes_clean_clone
      with_ci_parity_repo(tracker: actionable_tracker) { |paths| assert_successful_cleanup(paths) }
    end

    def test_tracker_queue_phase_precedes_bundle_install
      script = File.read(File.join(CheckCiParityRepoFixture::REPO_ROOT, "bin/check_ci_parity"))

      assert_operator script.index("bin/check_tracker_queue"), :<, script.index("bundle install")
    end
  end
end
