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
  CONTROLLERS_COP, VIEWS_COP = RAILS_AWARE_COP_NAMES
  LIB_TEMPLATE = "lib/templates/index.html.erb"
  LIB_TEMPLATE_SOURCE = "<%== user.account.owner.email %>\n"
  LIB_CONTROLLER = <<~RUBY
    class Admin::UsersController < ApplicationController
      def show
        User.find(1)
        AuditLog.recent
      end
    end
  RUBY

  # Per-cop project layouts for the Include-scope tests. `default` is the cop's
  # default Include pattern; `extra` is a pattern a project adds next to it.
  # `engine` and `app` are Rails-shaped paths the default scope covers, `extra_only`
  # matches only the extra pattern, and `unmatched` is covered by neither.
  CONTROLLER_SCOPE = {
    cop: CONTROLLERS_COP,
    default: "app/controllers/**/*.rb",
    extra: "lib/**/*",
    engine: "engines/blog/app/controllers/posts_controller.rb",
    excluded_engine: "engines/blog/app/controllers/legacy_controller.rb",
    app: "app/controllers/users_controller.rb",
    extra_only: "lib/admin/teams_controller.rb",
    excluded_extra: "lib/admin/legacy_controller.rb",
    unmatched: "script/stray_controller.rb",
    source: LIB_CONTROLLER
  }.freeze
  VIEW_SCOPE = {
    cop: VIEWS_COP,
    default: "app/views/**/*.{erb,haml,slim}",
    extra: "lib/**/*",
    engine: "packs/billing/app/views/invoices/show.html.erb",
    excluded_engine: "packs/billing/app/views/invoices/legacy.html.erb",
    app: "app/views/users/show.html.erb",
    extra_only: "lib/templates/index.html.erb",
    excluded_extra: "lib/templates/legacy.html.erb",
    unmatched: "script/stray.html.erb",
    source: LIB_TEMPLATE_SOURCE
  }.freeze

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

  def test_project_include_override_replaces_default_scope
    override = RAILS_AWARE_COP_NAMES.map { |name| "#{name}:\n  Include:\n    - 'lib/**/*'\n" }.join
    payload = run_fixture_scan(extra_config: override)

    assert_empty controllers_offenses(payload),
                 "A project Include override must take Metz/ControllersTooManyDirectCollaborators " \
                 "off app/controllers/"
    assert_empty views_offenses(payload),
                 "A project Include override must take Metz/ViewsDeepNavigation off app/views/"
  end

  def test_project_include_override_brings_a_template_outside_app_views_into_scope
    cop_names = lib_template_cop_names("Metz/ViewsDeepNavigation:\n  Include:\n    - 'lib/**/*'\n")

    assert_includes cop_names, "Metz/ViewsDeepNavigation",
                    "A project Include override must bring #{LIB_TEMPLATE} into scope"
    refute_includes cop_names, "Lint/Syntax", "#{LIB_TEMPLATE} must be read as ERB, not raw Ruby"
  end

  def test_template_outside_app_views_is_extracted_but_out_of_default_scope
    cop_names = lib_template_cop_names("")

    refute_includes cop_names, "Metz/ViewsDeepNavigation",
                    "#{LIB_TEMPLATE} is outside the default Metz/ViewsDeepNavigation scope"
    refute_includes cop_names, "Lint/Syntax", "#{LIB_TEMPLATE} must be read as ERB, not raw Ruby"
  end

  def test_project_include_override_brings_a_lib_controller_into_scope
    flagged = flagged_paths({ "lib/admin/users_controller.rb" => LIB_CONTROLLER },
                            "#{CONTROLLERS_COP}:\n  Include:\n    - 'lib/**/*'\n")

    assert_equal [[CONTROLLERS_COP, "lib/admin/users_controller.rb"]], flagged
  end

  def test_project_include_and_exclude_together_scope_lib_controllers
    files = { "lib/admin/users_controller.rb" => LIB_CONTROLLER, "lib/admin/teams_controller.rb" => LIB_CONTROLLER }
    flagged = flagged_paths(files, "#{CONTROLLERS_COP}:\n  Include:\n    - 'lib/**/*'\n  " \
                                   "Exclude:\n    - 'lib/admin/teams_controller.rb'\n")

    assert_equal [[CONTROLLERS_COP, "lib/admin/users_controller.rb"]], flagged
  end

  def test_project_include_and_exclude_together_scope_lib_templates
    files = { "lib/templates/index.html.erb" => LIB_TEMPLATE_SOURCE,
              "lib/templates/show.html.erb" => LIB_TEMPLATE_SOURCE }
    flagged = flagged_paths(files, "#{VIEWS_COP}:\n  Include:\n    - 'lib/**/*'\n  " \
                                   "Exclude:\n    - 'lib/templates/show.html.erb'\n")

    assert_equal [[VIEWS_COP, "lib/templates/index.html.erb"]], flagged
  end

  # By default both cops check app/controllers or app/views in engines and nested
  # apps. An Include that still lists the default pattern (inherit_mode merge, or
  # listed explicitly) keeps that scope and adds the extra paths, with Exclude
  # still applied; an Include without the default pattern replaces the scope.
  # Source: owner decision 2026-10-13 (cop-accuracy slice).
  def test_controllers_cop_checks_engine_and_nested_app_controllers_by_default
    assert_default_scope(CONTROLLER_SCOPE)
  end

  def test_views_cop_checks_engine_and_nested_app_views_by_default
    assert_default_scope(VIEW_SCOPE)
  end

  def test_controllers_cop_with_merged_include_keeps_default_scope_and_adds_extra_pattern
    assert_default_plus_extra_scope(CONTROLLER_SCOPE, merged_include_config(CONTROLLER_SCOPE))
  end

  def test_views_cop_with_merged_include_keeps_default_scope_and_adds_extra_pattern
    assert_default_plus_extra_scope(VIEW_SCOPE, merged_include_config(VIEW_SCOPE))
  end

  def test_controllers_cop_with_default_listed_next_to_extras_keeps_default_scope_and_adds_extra_pattern
    assert_default_plus_extra_scope(CONTROLLER_SCOPE, listed_include_config(CONTROLLER_SCOPE))
  end

  def test_views_cop_with_default_listed_next_to_extras_keeps_default_scope_and_adds_extra_pattern
    assert_default_plus_extra_scope(VIEW_SCOPE, listed_include_config(VIEW_SCOPE))
  end

  def test_controllers_cop_exclude_still_applies_with_merged_include
    assert_exclude_applies(CONTROLLER_SCOPE, merged_include_config(CONTROLLER_SCOPE))
  end

  def test_views_cop_exclude_still_applies_with_merged_include
    assert_exclude_applies(VIEW_SCOPE, merged_include_config(VIEW_SCOPE))
  end

  def test_controllers_cop_exclude_still_applies_with_default_listed_next_to_extras
    assert_exclude_applies(CONTROLLER_SCOPE, listed_include_config(CONTROLLER_SCOPE))
  end

  def test_views_cop_exclude_still_applies_with_default_listed_next_to_extras
    assert_exclude_applies(VIEW_SCOPE, listed_include_config(VIEW_SCOPE))
  end

  def test_controllers_cop_include_without_default_pattern_drops_engine_controllers
    assert_replaced_scope(CONTROLLER_SCOPE)
  end

  def test_views_cop_include_without_default_pattern_drops_engine_views
    assert_replaced_scope(VIEW_SCOPE)
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

  def run_fixture_scan(extra_config: "")
    with_fixture_scan_config(extra_config) do |config_path|
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

  def with_fixture_scan_config(extra_config)
    Dir.mktmpdir("metz-rails-aware-config") do |dir|
      path = File.join(dir, ".rubocop.yml")
      File.write(path, fixture_scan_config + extra_config)
      yield path
    end
  end

  def scope_files(scope, *keys)
    keys.to_h { |key| [scope.fetch(key), scope.fetch(:source)] }
  end

  def all_scope_files(scope)
    scope_files(scope, :engine, :excluded_engine, :app, :extra_only, :excluded_extra, :unmatched)
  end

  def merged_include_config(scope)
    "#{scope.fetch(:cop)}:\n  inherit_mode:\n    merge:\n      - Include\n  Include:\n    - '#{scope.fetch(:extra)}'\n"
  end

  def listed_include_config(scope)
    "#{scope.fetch(:cop)}:\n  Include:\n    - '#{scope.fetch(:default)}'\n    - '#{scope.fetch(:extra)}'\n"
  end

  def exclude_config(scope)
    "  Exclude:\n    - '#{scope.fetch(:excluded_engine)}'\n    - '#{scope.fetch(:excluded_extra)}'\n"
  end

  def flagged_for(scope, config)
    flagged_paths(all_scope_files(scope), config).map(&:last).sort
  end

  def assert_default_scope(scope)
    expected = [scope.fetch(:app), scope.fetch(:engine), scope.fetch(:excluded_engine)].sort

    assert_equal expected, flagged_for(scope, "")
  end

  def assert_default_plus_extra_scope(scope, config)
    expected = [scope.fetch(:app), scope.fetch(:engine), scope.fetch(:excluded_engine),
                scope.fetch(:extra_only), scope.fetch(:excluded_extra)].sort

    assert_equal expected, flagged_for(scope, config)
  end

  def assert_exclude_applies(scope, config)
    expected = [scope.fetch(:app), scope.fetch(:engine), scope.fetch(:extra_only)].sort

    assert_equal expected, flagged_for(scope, config + exclude_config(scope))
  end

  def assert_replaced_scope(scope)
    config = "#{scope.fetch(:cop)}:\n  Include:\n    - '#{scope.fetch(:extra)}'\n"

    assert_equal [scope.fetch(:excluded_extra), scope.fetch(:extra_only)].sort, flagged_for(scope, config)
  end

  def lib_template_cop_names(extra_config)
    project_offenses({ LIB_TEMPLATE => LIB_TEMPLATE_SOURCE }, extra_config).map(&:first)
  end

  def flagged_paths(files, extra_config)
    project_offenses(files, extra_config).select { |pair| RAILS_AWARE_COP_NAMES.include?(pair.first) }.sort
  end

  # Runs plain rubocop over `files` in a temp project; returns [cop_name, path] pairs.
  def project_offenses(files, extra_config)
    Dir.mktmpdir("metz-rails-aware-project") do |dir|
      File.write(File.join(dir, ".rubocop.yml"), fixture_scan_config + extra_config)
      files.each do |path, source|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        File.write(File.join(dir, path), source)
      end
      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
        "bundle", "exec", "rubocop", "--cache", "false", "--format", "json", *files.keys,
        chdir: dir
      )
      refute_empty stdout, "Expected JSON on stdout but got status=#{status.exitstatus}, stderr:\n#{stderr}"
      JSON.parse(stdout).fetch("files").flat_map { |f| f["offenses"].map { |o| [o["cop_name"], f["path"]] } }
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
