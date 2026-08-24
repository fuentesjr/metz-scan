# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "rubygems"
require "tmpdir"

module MetzScan
  # Dependabot's bundler updater evaluates gemspecs in a sparse temp tree that
  # only materializes require_relative targets (version.rb), not the full
  # package. Regression coverage for #41.
  class GemspecDependabotEvalTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    METZ_SCAN = {
      name: "metz-scan",
      gemspec: "metz-scan.gemspec",
      version: "lib/metz_scan/version.rb",
      dependency: "rubocop-metz"
    }.freeze
    RUBOCOP_METZ = {
      name: "rubocop-metz",
      gemspec: "rubocop-metz/rubocop-metz.gemspec",
      version: "rubocop-metz/lib/rubocop/metz/version.rb",
      version_relative: "lib/rubocop/metz/version.rb",
      dependency: "rubocop"
    }.freeze

    def test_metz_scan_gemspec_evaluates_in_sparse_tree
      with_sparse_spec(METZ_SCAN) do |spec|
        assert_sparse_identity(spec, METZ_SCAN)
        assert_equal ["~> #{spec.version}"], sparse_requirements(spec, METZ_SCAN)
      end
    end

    def test_rubocop_metz_gemspec_evaluates_in_sparse_tree
      with_sparse_spec(RUBOCOP_METZ) do |spec|
        assert_sparse_identity(spec, RUBOCOP_METZ)
        assert_equal ["~> 1.80"], sparse_requirements(spec, RUBOCOP_METZ)
      end
    end

    private

    def with_sparse_spec(fixture)
      Dir.mktmpdir("metz-scan-gemspec-sparse") do |dir|
        yield load_spec(write_sparse_tree(dir, fixture))
      end
    end

    def assert_sparse_identity(spec, fixture)
      refute_nil spec, "#{fixture[:name]}.gemspec must evaluate in a Dependabot-like sparse tree"
      assert_equal fixture[:name], spec.name
    end

    def sparse_requirements(spec, fixture)
      dependency = spec.dependencies.find { |item| item.name == fixture[:dependency] }
      dependency.requirement.requirements.map { |op, version| "#{op} #{version}" }
    end

    def write_sparse_tree(dir, fixture)
      root = File.join(dir, fixture.fetch(:name))
      dest = File.join(root, File.basename(fixture.fetch(:gemspec)))
      stage_sparse_files(root, dest, fixture)
      dest
    end

    def stage_sparse_files(root, dest, fixture)
      version_dest = File.join(root, fixture[:version_relative] || fixture.fetch(:version))
      FileUtils.mkdir_p(File.dirname(version_dest))
      FileUtils.cp(repo_path(fixture.fetch(:gemspec)), dest)
      FileUtils.cp(repo_path(fixture.fetch(:version)), version_dest)
    end

    def load_spec(path)
      absolute = File.expand_path(path)
      Dir.chdir(File.dirname(absolute)) { Gem::Specification.load(absolute) }
    end

    def repo_path(path)
      File.join(REPO_ROOT, path)
    end
  end
end
