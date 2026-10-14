# frozen_string_literal: true

require "rake/testtask"
require_relative "test/support/test_file_groups"
require_relative "test/support/parallel_test_runner"

def run_test_processes(jobs)
  name = %w[TEST TESTOPTS TESTOPT TEST_OPTS TEST_OPT].find { |key| ENV.key?(key) }
  abort "#{name} is ignored here; use `rake test:fast #{name}=...` or the single-file command in CLAUDE.md." if name
  abort "Test processes failed." unless MetzScan::ParallelTestRunner.new(jobs).run.success?
end

def slow_test_jobs
  MetzScan::TestFileGroups.slow_files_longest_first.map { |file| MetzScan::ParallelTestRunner::Job.new(file, [file]) }
end

def fast_test_job
  files = MetzScan::TestFileGroups.fast_files
  MetzScan::ParallelTestRunner::Job.new("fast group (#{files.size} files)", files)
end

desc "Run the full test suite (fast group in one process beside the slow files; TEST_JOBS caps concurrency)"
task(:test) { run_test_processes([fast_test_job, *slow_test_jobs]) }

desc "Run fast unit-style tests"
Rake::TestTask.new("test:fast") do |t|
  t.libs.push(*MetzScan::ParallelTestRunner::LOAD_PATHS)
  t.test_files = MetzScan::TestFileGroups.fast_files
  t.warning = false
end

desc "Run slow subprocess and integration tests, one process per file (TEST_JOBS caps concurrency)"
task("test:slow") { run_test_processes(slow_test_jobs) }

task default: :test
