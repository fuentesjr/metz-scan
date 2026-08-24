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
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["github_repo"] = "ssh://github.com/fuentesjr/metz-scan"
  spec.metadata["github_package_uri"] = "https://github.com/users/fuentesjr/packages/rubygems/package/rubocop-metz"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Metz::Plugin"

  # Resolve files from the gemspec directory so evaluation is CWD-independent.
  # Do not raise when the entrypoint is absent: Dependabot evaluates gemspecs in
  # a sparse tree that only materializes require_relative targets (#41). Package
  # completeness is checked by release_metadata_test against the full checkout.
  gem_root = __dir__
  spec.files = Dir.glob("{lib,config}/**/*", File::FNM_DOTMATCH, base: gem_root)
                  .reject { |f| File.directory?(File.join(gem_root, f)) } +
               ["LICENSE", "rubocop-metz.gemspec"].select { |f| File.exist?(File.join(gem_root, f)) }
  spec.require_paths = ["lib"]

  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", "~> 1.80"
  spec.add_dependency "rubocop-ast", "~> 1.49"
end
