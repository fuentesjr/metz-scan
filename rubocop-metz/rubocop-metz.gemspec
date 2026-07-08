# frozen_string_literal: true

require_relative "lib/rubocop/metz/version"

Gem::Specification.new do |spec|
  spec.name        = "rubocop-metz"
  spec.version     = RuboCop::Metz::VERSION
  spec.authors     = ["Salvador Fuentes Jr"]
  spec.email       = ["fuentesjr@duck.com"]

  spec.summary     = "Sandi-Metz-inspired RuboCop cops."
  spec.description = "A RuboCop plugin that ships custom cops capturing " \
                     "Sandi-Metz-style design heuristics for Ruby and Rails code."
  spec.homepage    = "https://github.com/fuentesjr/metz-scan"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["github_repo"] = "ssh://github.com/fuentesjr/metz-scan"
  spec.metadata["github_package_uri"] = "https://github.com/users/fuentesjr/packages/rubygems/package/rubocop-metz"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Metz::Plugin"

  spec.files = Dir.glob("{lib,config}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) } +
               ["LICENSE", "rubocop-metz.gemspec"].select { |f| File.exist?(f) }
  # This gemspec's Dir.glob is relative to the build CWD, so building from the
  # repo root (`gem build rubocop-metz/rubocop-metz.gemspec`) would silently
  # package the wrapper's lib/metz_scan files instead of these cops. Fail loudly
  # instead of shipping a corrupt gem. Build from this directory:
  #   cd rubocop-metz && gem build rubocop-metz.gemspec
  unless spec.files.include?("lib/rubocop-metz.rb")
    raise "rubocop-metz.gemspec: lib/rubocop-metz.rb missing from packaged files; " \
          "build from rubocop-metz/ (cd rubocop-metz && gem build rubocop-metz.gemspec)."
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", "~> 1.80"
  spec.add_dependency "rubocop-ast", "~> 1.49"
end
