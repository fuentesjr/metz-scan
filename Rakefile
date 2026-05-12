# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "rubocop-metz/lib"
  t.libs << "rubocop-metz/test"
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList[
    "rubocop-metz/test/**/*_test.rb",
    "rubocop-metz/test/integration/**/*_test.rb",
    "test/**/*_test.rb"
  ]
  t.warning = false
end

task default: :test
