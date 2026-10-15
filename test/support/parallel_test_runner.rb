# frozen_string_literal: true

require "etc"
require "fileutils"
require "open3"
require "rbconfig"
require_relative "test_process_paths"

module MetzScan
  # Runs test jobs (each a list of test files) as separate ruby processes, at
  # most TEST_JOBS at once (TEST_JOBS=1 runs them serially). Processes, not
  # threads: the tests swap $stdout/$stderr, mutate ENV, and call Dir.chdir.
  # Each job's combined output is printed whole when it finishes. A job passes
  # only if it exits 0 and prints a minitest summary line.
  class ParallelTestRunner
    DEFAULT_JOBS = 4
    LOAD_PATHS = %w[rubocop-metz/lib rubocop-metz/test lib tools/lib test].freeze
    LOADER = "ARGV.shift(ARGV.size).each { |file| require File.expand_path(file) }"
    SUMMARY = /^(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips$/
    COUNT_NAMES = %w[runs assertions failures errors skips].freeze

    Job = Struct.new(:label, :files)
    Result = Struct.new(:job, :output, :status, :seconds) do
      def counts = output.scan(SUMMARY).last&.map(&:to_i)
      def success? = status.success? && !counts.nil?
      def failure_label = status.success? ? "#{job.label} (no minitest summary)" : job.label
    end

    def self.job_limit
      value = ENV.fetch("TEST_JOBS", DEFAULT_JOBS.to_s)
      limit = Integer(value, exception: false) or abort "TEST_JOBS must be an integer, got #{value.inspect}"
      limit.clamp(1, Etc.nprocessors)
    end

    def initialize(jobs, limit: self.class.job_limit)
      @jobs = jobs
      @limit = limit
      @results = []
      @lock = Mutex.new
    end

    def run
      started = clock
      start_workers(Queue.new.tap { |q| @jobs.each { |job| q << job } }.close).each(&:join)
      report(clock - started)
      self
    end

    def success? = !@results.empty? && @results.all?(&:success?)

    private

    def start_workers(queue)
      Array.new([@limit, @jobs.size].min) { Thread.new { work(queue) } }
    end

    def work(queue)
      while (job = queue.pop)
        result = run_job(job)
        @lock.synchronize { record(result) }
      end
    end

    def run_job(job)
      started = clock
      output, status = capture(command(job.files))
      Result.new(job, output, status, clock - started)
    end

    # A killed process skips its teardown, so remove its scan scratch dir here.
    def capture(command)
      Open3.popen2e(*command) do |stdin, out, wait|
        stdin.close
        [out.read, wait.value].tap { FileUtils.rm_rf(TestProcessPaths.scan_tmp_root(wait.pid)) }
      end
    end

    def command(files)
      [RbConfig.ruby, *LOAD_PATHS.flat_map { |path| ["-I", path] }, "-e", LOADER, *files]
    end

    def record(result)
      @results << result
      $stdout.puts "==> #{result.job.label} (#{format('%.1fs', result.seconds)})"
      $stdout.puts result.output
      $stdout.flush
    end

    def report(seconds)
      $stdout.puts summary_line(seconds)
      $stdout.puts "No test files matched; nothing ran." if @results.empty?
      failed = @results.reject(&:success?).map(&:failure_label)
      $stdout.puts "Failed test processes: #{failed.join(', ')}" unless failed.empty?
    end

    def summary_line(seconds)
      counts = COUNT_NAMES.zip(totals).map { |name, total| "#{total} #{name}" }
      "#{@results.size} test processes (#{@limit} at a time) in #{format('%.1fs', seconds)}: #{counts.join(', ')}"
    end

    def totals
      @results.filter_map(&:counts).inject([0] * COUNT_NAMES.size) { |sum, counts| sum.zip(counts).map(&:sum) }
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
