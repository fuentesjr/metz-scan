# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "open3"
require "yaml"

class M4CrossCopFixtureIntegrationTest < Minitest::Test
  REPO_ROOT = File.expand_path("../../..", __dir__)
  FIXTURE_DIR = "test/fixtures/sample_app"
  M4_COP_NAMES = %w[
    Metz/ControllersTooManyDirectCollaborators
    Metz/ViewsDeepNavigation
  ].freeze

  def test_full_fixture_run_produces_offenses_for_both_m4_cops_under_fixture_paths
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

  def test_clean_manifest_files_are_not_flagged_by_m4_cops
    payload = run_fixture_scan
    by_path = offenses_by_path(payload)
    manifest = YAML.load_file(File.join(REPO_ROOT, FIXTURE_DIR, ".fixture_manifest.yml"))

    clean_paths(manifest).each do |path|
      hits = (by_path[path] || []) & M4_COP_NAMES

      assert_empty hits,
                   "Clean manifest path #{path.inspect} flagged by #{hits.inspect}"
    end
  end

  private

  def run_fixture_scan
    stdout, stderr, status = Open3.capture3(
      { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
      "bundle", "exec", "rubocop",
      "--plugin", "rubocop-metz",
      "--format", "json",
      "#{FIXTURE_DIR}/",
      chdir: REPO_ROOT
    )

    refute_empty stdout, "Expected JSON on stdout but got status=#{status.exitstatus}, stderr:\n#{stderr}"
    JSON.parse(stdout)
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
