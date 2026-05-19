#!/usr/bin/env ruby
# frozen_string_literal: true

repo_root = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(repo_root, "lib"))

require "pathname"
require "metz_scan/analyzers/repeated_branching"

paths = ARGV.empty? ? [repo_root] : ARGV
workspace = ARGV.empty?
index = MetzScan::ProjectIndex.build(paths, workspace: workspace)
analyzer = MetzScan::Analyzers::RepeatedBranching.new(paths: paths, index: index)
findings = analyzer.call

def display_path(path)
  Pathname.new(path).relative_path_from(Pathname.pwd).to_s
rescue ArgumentError
  path
end

puts "backend: #{index.backend_name}"
puts "workspace: #{workspace}"
puts "rule_id: #{MetzScan::Analyzers::RepeatedBranching::RULE_ID}"
puts "findings: #{findings.size}"

findings.each do |finding|
  puts "- #{finding.decision} repeated across #{finding.occurrences.map(&:path).uniq.size} files: " \
       "#{finding.branch_values.join(', ')}"
  finding.occurrences.each { |occurrence| puts "  #{display_path(occurrence.path)}:#{occurrence.line}" }
end
