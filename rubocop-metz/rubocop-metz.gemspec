# frozen_string_literal: true

require_relative "lib/rubocop/metz/version"

Gem::Specification.new do |spec|
  spec.name        = "rubocop-metz"
  spec.version     = RuboCop::Metz::VERSION
  spec.authors     = ["Salvador Fuentes Jr"]
  spec.email       = ["metz_scan@example.com"]

  spec.summary     = "Sandi-Metz-inspired RuboCop cops."
  spec.description = "A RuboCop plugin that ships custom cops capturing " \
                     "Sandi-Metz-style design heuristics for Ruby and Rails code."
  spec.homepage    = "https://github.com/salfuentes/metz_scan"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"]             = spec.homepage
  spec.metadata["default_lint_roller_plugin"]  = "RuboCop::Metz::Plugin"

  spec.files = Dir.glob("{lib,config}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) } +
               ["rubocop-metz.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", "~> 1.80"
  spec.add_dependency "rubocop-ast", "~> 1.49"
end
