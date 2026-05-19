#!/usr/bin/env ruby
# frozen_string_literal: true

repo_root = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(repo_root, "lib"))

require "metz_scan/analyzers/inheritance_descendants"

base_name = ARGV.shift
unless base_name
  warn "Usage: bundle exec ruby script/inheritance_descendants_spike.rb BASE_NAME [PATH ...]"
  exit 64
end

paths = ARGV.empty? ? [repo_root] : ARGV
workspace = ARGV.empty?
index = MetzScan::ProjectIndex.build(paths, workspace: workspace)

unless index.available?
  warn "Rubydex-backed project index unavailable: #{index.reason}"
  warn "Run `bundle config set --local with rubydex && bundle install` before this spike."
  exit 2
end

analyzer = MetzScan::Analyzers::InheritanceDescendants.new(index: index, base_names: base_name)
finding = analyzer.call.first
descendants = finding&.descendants || []

puts "backend: #{index.backend_name}"
puts "workspace: #{workspace}"
puts "base_name: #{base_name}"
puts "rule_id: #{MetzScan::Analyzers::InheritanceDescendants::RULE_ID}"
puts "descendants: #{descendants.size}"
descendants.each { |name| puts "  - #{name}" }
puts "  (none)" if descendants.empty?
