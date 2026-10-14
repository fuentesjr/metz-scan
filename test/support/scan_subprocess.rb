# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  # Runs `bin/metz-scan scan` in a subprocess against throwaway projects built
  # outside the repo (the repo's own .rubocop.yml must not affect discovery).
  module ScanSubprocessSupport
    REPO_ROOT = File.expand_path("../..", __dir__)

    Result = Struct.new(:stdout, :stderr, :status) do
      def exitstatus = status.exitstatus
      def json = JSON.parse(stdout)
    end

    # Builds a project from { "relative/path" => "content" } and yields its realpath.
    def with_project(files = {})
      Dir.mktmpdir("metz-scan-subprocess-test") do |dir|
        root = File.realpath(dir)
        files.each { |relative, content| write_project_file(root, relative, content) }
        yield root
      end
    end

    def write_project_file(root, relative, content)
      path = File.join(root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    # Runs `metz-scan scan *args` from `chdir`; `shim` is Ruby source loaded into the subprocess.
    def scan_subprocess(chdir, *args, shim: nil)
      with_scan_env(shim) do |env|
        Result.new(*Open3.capture3(env, *scan_command(args), chdir: chdir))
      end
    end

    def assert_exit_2_naming(result, *causes)
      assert_equal 2, result.exitstatus, failure_context(result)
      assert causes.any? { |cause| result.stderr.include?(cause) },
             "expected stderr to name one of #{causes.inspect}\n#{failure_context(result)}"
    end

    # Exit 2 fails closed: the cause is on stderr and stdout carries no report.
    def assert_fails_closed(result, *causes)
      assert_exit_2_naming(result, *causes)
      assert_empty result.stdout, "expected nothing on stdout\n#{failure_context(result)}"
    end

    # Every file under `root` (dotfiles included) as { relative path => bytes }.
    def project_snapshot(root)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: root).reject { |path| File.directory?(File.join(root, path)) }
         .to_h { |path| [path, File.binread(File.join(root, path))] }
    end

    def failure_context(result)
      "exit=#{result.exitstatus.inspect}\nstdout=\n#{result.stdout}\nstderr=\n#{result.stderr}"
    end

    private

    def scan_command(args)
      ["bundle", "exec", RbConfig.ruby, File.join(REPO_ROOT, "bin/metz-scan"), "scan", *args]
    end

    def with_scan_env(shim)
      Dir.mktmpdir("metz-scan-subprocess-support") do |support_dir|
        env = base_env(File.join(support_dir, "rubocop_cache"))
        env["RUBYOPT"] = shim_rubyopt(support_dir, shim) if shim
        yield env
      end
    end

    def base_env(cache_root)
      { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile"), "RUBOCOP_CACHE_ROOT" => cache_root }
    end

    def shim_rubyopt(dir, source)
      path = File.join(dir, "shim.rb")
      File.write(path, format(source, lib: File.join(REPO_ROOT, "lib")))
      [ENV.fetch("RUBYOPT", nil), "-r#{path}"].compact.join(" ")
    end
  end
end
