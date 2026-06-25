# frozen_string_literal: true

require "rake/testtask"
require_relative "test/support/test_file_groups"

def configure_test_task(task, files)
  task.libs.push("rubocop-metz/lib", "rubocop-metz/test", "lib", "test")
  task.test_files = files
  task.warning = false
end

desc "Run the full test suite"
Rake::TestTask.new(:test) { |t| configure_test_task(t, MetzScan::TestFileGroups.all_files) }

desc "Run fast unit-style tests"
Rake::TestTask.new("test:fast") { |t| configure_test_task(t, MetzScan::TestFileGroups.fast_files) }

desc "Run slow subprocess and integration tests"
Rake::TestTask.new("test:slow") { |t| configure_test_task(t, MetzScan::TestFileGroups.slow_files) }

task default: :test
