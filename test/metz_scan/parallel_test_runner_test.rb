# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "support/parallel_test_runner"

module MetzScan
  class ParallelTestRunnerTest < Minitest::Test
    CASES = {
      pass: "require 'minitest/autorun'\nclass PassT < Minitest::Test; def test_a = assert(true); end\n",
      failure: "require 'minitest/autorun'\nclass FailT < Minitest::Test; def test_a = assert(false); end\n",
      load_error: "require 'minitest/autorun'\nraise 'boom at load'\n",
      killed: "require 'minitest/autorun'\n" \
              "class KilledT < Minitest::Test; def test_a = Process.kill('KILL', Process.pid); end\n",
      no_summary: "class NoAutorunT; def test_a = raise('never runs'); end\n",
      killed_with_scratch: "require 'fileutils'\nrequire 'support/test_process_paths'\n" \
                           "FileUtils.mkdir_p(MetzScan::TestProcessPaths.scan_tmp_root)\n" \
                           "puts \"pid=\#{Process.pid}\"; $stdout.flush; Process.kill('KILL', Process.pid)\n"
    }.freeze

    def test_passes_when_every_process_exits_zero_with_a_summary
      runner, output = run_cases(:pass)

      assert_predicate runner, :success?, output
      refute_match(/^Failed test processes:/, output)
    end

    def test_process_exiting_zero_without_a_minitest_summary_fails
      runner, output = run_cases(:no_summary)

      refute_predicate runner, :success?, output
      assert_includes failed_line(output), "no_summary (no minitest summary)"
    end

    def test_run_with_no_test_processes_fails
      runner, output = run_cases

      refute_predicate runner, :success?
      assert_includes output, "No test files matched"
    end

    def test_removes_the_scan_scratch_dir_of_a_killed_process
      _runner, output = run_cases(:killed_with_scratch)
      pid = output[/^pid=(\d+)$/, 1]

      refute_nil pid, output
      refute_path_exists TestProcessPaths.scan_tmp_root(pid)
    end

    def test_failed_line_names_every_failing_process
      runner, output = run_cases(:pass, :failure, :load_error, :killed, :no_summary)

      refute_predicate runner, :success?
      assert_equal "Failed test processes: failure, killed, load_error, no_summary (no minitest summary)",
                   sorted_failed_line(output)
    end

    private

    def run_cases(*names)
      Dir.mktmpdir("metz-scan-parallel-runner-test") do |dir|
        runner = ParallelTestRunner.new(names.map { |name| job(dir, name) }, limit: 2)
        output, = capture_io { runner.run }
        [runner, output]
      end
    end

    def job(dir, name)
      path = File.join(dir, "#{name}_test.rb")
      File.write(path, CASES.fetch(name))
      ParallelTestRunner::Job.new(name.to_s, [path])
    end

    def failed_line(output)
      output.lines.grep(/^Failed test processes:/).first.to_s.chomp
    end

    def sorted_failed_line(output)
      labels = failed_line(output).delete_prefix("Failed test processes: ").split(", ")
      "Failed test processes: #{labels.sort.join(', ')}"
    end
  end
end
