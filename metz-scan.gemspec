# frozen_string_literal: true

require_relative "lib/metz_scan/version"

Gem::Specification.new do |spec|
  spec.name        = "metz-scan"
  spec.version     = MetzScan::VERSION
  spec.authors     = ["Salvador Fuentes Jr"]
  spec.email       = ["metz_scan@example.com"]

  spec.summary     = "Sandi-Metz-inspired CLI wrapper around RuboCop."
  spec.description = "metz-scan is the user-facing CLI for the Sandi-Metz-inspired " \
                     "code-quality toolchain. It runs RuboCop with the rubocop-metz " \
                     "plugin and renders developer-friendly reports."
  spec.homepage    = "https://github.com/fuentesjr/metz-scan"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["github_repo"]     = "ssh://github.com/fuentesjr/metz-scan"

  spec.files = Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) } +
               Dir.glob("bin/metz-scan").select { |f| File.file?(f) } +
               ["LICENSE", "metz-scan.gemspec"].select { |f| File.exist?(f) }
  spec.bindir        = "bin"
  spec.executables   = ["metz-scan"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubocop-metz", "~> #{MetzScan::VERSION}"
end
