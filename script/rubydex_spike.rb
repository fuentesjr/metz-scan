#!/usr/bin/env ruby
# frozen_string_literal: true

repo_root = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(repo_root, "lib"))

require "metz_scan/project_index"

paths = ARGV.empty? ? [repo_root] : ARGV
workspace = ARGV.empty?
index = MetzScan::ProjectIndex.build(paths, workspace: workspace)

unless index.available?
  warn "Rubydex-backed project index unavailable: #{index.reason}"
  warn "Run `bundle config set --local with rubydex && bundle install` before this spike."
  exit 2
end

puts "backend: #{index.backend_name}"
puts "workspace: #{workspace}"
puts "indexed_files: #{index.indexed_files.size}"
puts "declarations: #{index.declarations.size}"
puts "ruby_documents: #{index.documents.size}"

minitest_descendants = index.descendants_of("Minitest::Test")
puts "minitest_test_descendants:"
minitest_descendants.each { |name| puts "  - #{name}" }
puts "  (none)" if minitest_descendants.empty?

metz_declarations = index.declarations.map(&:name).grep(/\ARuboCop::Cop::Metz::[^:()#@]+\z/).sort
puts "metz_cop_declarations:"
metz_declarations.each { |name| puts "  - #{name}" }
puts "  (none)" if metz_declarations.empty?

bridge_references = index.constant_references_to("RuboCop::Cop::Metz::OnSendCsendBridge")
puts "references_to RuboCop::Cop::Metz::OnSendCsendBridge: #{bridge_references.size}"

puts "diagnostics: #{index.diagnostics.size}"
puts "index_errors: #{index.index_errors.size}"
