# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

class RailsAwareCopsFixtureIntegrationTest < Minitest::Test
  REPO_ROOT = File.expand_path("../../..", __dir__)
  FIXTURE_DIR = "test/fixtures/sample_app"
  RAILS_AWARE_COP_NAMES = %w[
    Metz/ControllersTooManyDirectCollaborators
    Metz/ViewsDeepNavigation
  ].freeze

  def test_full_fixture_run_produces_offenses_for_both_rails_aware_cops_under_fixture_paths
    payload = run_fixture_scan

    refute_empty controllers_offenses(payload),
                 "Expected >= 1 Metz/ControllersTooManyDirectCollaborators offense in fixture scan"
    refute_empty views_offenses(payload),
                 "Expected >= 1 Metz/ViewsDeepNavigation offense in fixture scan"

    payload.fetch("files").each do |file|
      next if file["offenses"].empty?

      path = file["path"]
      assert path.start_with?("#{FIXTURE_DIR}/"),
             "Offense path #{path.inspect} is outside #{FIXTURE_DIR}/"
    end
  end

  def test_clean_manifest_files_are_not_flagged_by_rails_aware_cops
    payload = run_fixture_scan
    by_path = offenses_by_path(payload)
    manifest = YAML.load_file(File.join(REPO_ROOT, FIXTURE_DIR, ".fixture_manifest.yml"))

    clean_paths(manifest).each do |path|
      hits = (by_path[path] || []) & RAILS_AWARE_COP_NAMES

      assert_empty hits,
                   "Clean manifest path #{path.inspect} flagged by #{hits.inspect}"
    end
  end

  def test_unrelated_output_path_does_not_enable_sample_fixture_scan
    Dir.mktmpdir("metz-rails-aware-output") do |dir|
      output_path = File.join(dir, "test/fixtures/sample_app-report.json")
      FileUtils.mkdir_p(File.dirname(output_path))

      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
        "bundle", "exec", "rubocop",
        "--plugin", "rubocop-metz",
        "--only", RAILS_AWARE_COP_NAMES.join(","),
        "--format", "json",
        "--out", output_path,
        chdir: REPO_ROOT
      )

      assert status.success?,
             "Unrelated ARGV containing #{FIXTURE_DIR.inspect} must not scan deliberate fixtures; " \
             "stdout=#{stdout.inspect}, stderr=#{stderr}"
      payload = JSON.parse(File.read(output_path))
      assert_empty controllers_offenses(payload)
      assert_empty views_offenses(payload)
    end
  end

  private

  def run_fixture_scan
    with_fixture_scan_config do |config_path|
      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
        "bundle", "exec", "rubocop",
        "--config", config_path,
        "--format", "json",
        "#{FIXTURE_DIR}/",
        chdir: REPO_ROOT
      )

      refute_empty stdout, "Expected JSON on stdout but got status=#{status.exitstatus}, stderr:\n#{stderr}"
      JSON.parse(stdout)
    end
  end

  def with_fixture_scan_config
    Dir.mktmpdir("metz-rails-aware-config") do |dir|
      path = File.join(dir, ".rubocop.yml")
      File.write(path, fixture_scan_config)
      yield path
    end
  end

  def fixture_scan_config
    <<~YAML
      plugins:
        - rubocop-metz

      AllCops:
        TargetRubyVersion: 3.3
        NewCops: disable
        SuggestExtensions: false
        Include:
          - "**/*.rb"
          - "**/*.erb"
          - "**/*.haml"
          - "**/*.slim"
    YAML
  end

  def controllers_offenses(payload)
    payload.fetch("files").flat_map do |f|
      f["offenses"].select { |o| o["cop_name"] == "Metz/ControllersTooManyDirectCollaborators" }
    end
  end

  def views_offenses(payload)
    payload.fetch("files").flat_map do |f|
      f["offenses"].select { |o| o["cop_name"] == "Metz/ViewsDeepNavigation" }
    end
  end

  def offenses_by_path(payload)
    payload.fetch("files").to_h do |file|
      [file["path"], file["offenses"].map { |o| o["cop_name"] }]
    end
  end

  def clean_paths(manifest)
    controllers = (manifest.dig("controllers", "clean") || [])
                  .map { |b| "#{FIXTURE_DIR}/app/controllers/#{b}" }
    views = (manifest.dig("views", "clean") || [])
            .map { |p| "#{FIXTURE_DIR}/#{p}" }
    controllers + views
  end
end
