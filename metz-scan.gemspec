# frozen_string_literal: true

require_relative "lib/metz_scan/version"

Gem::Specification.new do |spec|
  spec.name        = "metz-scan"
  spec.version     = MetzScan::VERSION
  spec.authors     = ["Salvador Fuentes Jr"]
  spec.email       = ["fuentesjr@duck.com"]

  spec.summary     = "Sandi-Metz-inspired CLI wrapper around RuboCop."
  spec.description = "metz-scan is the user-facing CLI for the Sandi-Metz-inspired " \
                     "code-quality toolchain. It runs RuboCop with the rubocop-metz " \
                     "plugin and renders developer-friendly reports."
  spec.homepage    = "https://github.com/fuentesjr/metz-scan"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["github_repo"] = "ssh://github.com/fuentesjr/metz-scan"
  spec.metadata["github_package_uri"] = "https://github.com/users/fuentesjr/packages/rubygems/package/metz-scan"

  # Resolve files from the gemspec directory so evaluation is CWD-independent.
  # Do not raise when the entrypoint is absent: Dependabot evaluates gemspecs in
  # a sparse tree that only materializes require_relative targets (#41). Package
  # completeness is checked by release_metadata_test against the full checkout.
  gem_root = __dir__
  spec.files = Dir.glob("lib/**/*", File::FNM_DOTMATCH, base: gem_root)
                  .reject { |f| File.directory?(File.join(gem_root, f)) } +
               Dir.glob("bin/metz-scan", base: gem_root)
                  .select { |f| File.file?(File.join(gem_root, f)) } +
               ["LICENSE", "metz-scan.gemspec"].select { |f| File.exist?(File.join(gem_root, f)) }
  spec.bindir        = "bin"
  spec.executables   = ["metz-scan"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubocop-metz", "~> #{MetzScan::VERSION}"
end
