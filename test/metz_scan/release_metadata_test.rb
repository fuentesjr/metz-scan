# frozen_string_literal: true

require "minitest/autorun"
require "rubygems"

module MetzScan
  class ReleaseMetadataTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)

    def test_gem_versions_are_aligned
      assert_equal metz_scan_spec.version, rubocop_metz_spec.version
    end

    def test_metz_scan_depends_on_matching_rubocop_metz_family
      dependency = dependency_for(metz_scan_spec, "rubocop-metz")

      assert_equal ["~> #{metz_scan_spec.version}"], dependency_requirements(dependency)
    end

    def test_gemspecs_keep_release_metadata
      assert_release_metadata metz_scan_spec, package: "metz-scan"
      assert_release_metadata rubocop_metz_spec, package: "rubocop-metz"
    end

    def test_gem_file_lists_include_runtime_files_only
      assert_runtime_file_list metz_scan_spec, expected: metz_scan_runtime_file
      assert_runtime_file_list rubocop_metz_spec, expected: "lib/rubocop/metz/plugin.rb"
    end

    private

    def assert_release_metadata(spec, package:)
      assert_equal ">= 3.3", spec.required_ruby_version.to_s
      assert_equal ["fuentesjr@duck.com"], spec.email
      assert_equal "https://github.com/fuentesjr/metz-scan", spec.homepage
      assert_equal "https://github.com/users/fuentesjr/packages/rubygems/package/#{package}",
                   spec.metadata.fetch("github_package_uri")
    end

    def assert_runtime_file_list(spec, expected:)
      assert_includes spec.files, expected
      refute(runtime_excluded_path?(spec))
    end

    def dependency_requirements(dependency)
      dependency.requirement.requirements.map { |op, version| "#{op} #{version}" }
    end

    def metz_scan_runtime_file
      "lib/metz_scan/calibration/project_analyzer_evidence_runner/markdown_renderer.rb"
    end

    def runtime_excluded_path?(spec)
      spec.files.any? { |path| path.start_with?("test/", "tmp/", "logs/") }
    end

    def dependency_for(spec, name)
      spec.dependencies.find { |dependency| dependency.name == name }
    end

    def metz_scan_spec
      @metz_scan_spec ||= load_spec(repo_path("metz-scan.gemspec"))
    end

    def rubocop_metz_spec
      @rubocop_metz_spec ||= load_spec(repo_path("rubocop-metz/rubocop-metz.gemspec"))
    end

    def load_spec(path)
      Dir.chdir(File.dirname(path)) { Gem::Specification.load(File.basename(path)) }
    end

    def repo_path(path)
      File.join(REPO_ROOT, path)
    end
  end
end
