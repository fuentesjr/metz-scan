# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "json"

class CopMetzViewsDeepNavigationTest < Minitest::Test
  include Metz::Test::CopHelper

  VIEW_PATH = "app/views/users/index.html.erb"
  REPO_ROOT = File.expand_path("../../../..", __dir__)
  FIXTURE_DIR = File.join(REPO_ROOT, "spec/fixtures/sample_app")

  def cop_class
    RuboCop::Cop::Metz::ViewsDeepNavigation
  end

  def cop_config
    { "MaxChainLength" => 3, "Severity" => "refactor" }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name("Metz/ViewsDeepNavigation")

    assert_equal RuboCop::Cop::Metz::ViewsDeepNavigation, klass
  end

  def test_default_yaml_carries_required_keys
    yaml = YAML.load_file(File.expand_path("../../../config/default.yml", __dir__))
    entry = yaml.fetch("Metz/ViewsDeepNavigation")

    assert_equal true, entry["Enabled"]
    assert_equal 3, entry["MaxChainLength"]
    assert_equal "refactor", entry["Severity"]
    inc = Array(entry["Include"])
    refute_empty inc
    assert(inc.all? { |g| g.start_with?("app/views/") },
           "Include must be scoped to app/views/")
    combined = inc.join(" ")
    %w[erb haml slim].each { |ext| assert_includes combined, ext }
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::ViewsDeepNavigation.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_fires_on_violating_object_graph_chain
    source = "current_user.account.subscription.plan.name"

    metz_inspect(source, VIEW_PATH)

    assert_equal 1, view_offenses.size,
                 "Expected one offense, got: #{view_offenses.map(&:message).inspect}"
  end

  def test_silent_on_value_object_chain
    refute_offense('name.upcase.strip.split(" ").first', file: VIEW_PATH)
  end

  def test_silent_on_short_chain
    refute_offense("user.profile.name", file: VIEW_PATH)
  end

  def test_silent_on_files_outside_app_views
    refute_offense("a.b.c.d.e.f", file: "lib/template.erb")
  end

  def test_silent_on_non_view_paths_even_with_deep_chain
    refute_offense("a.b.c.d.e.f", file: "app/models/user.rb")
  end

  def test_violating_view_fixtures_fire_at_least_one_offense
    violating = manifest.fetch("views").fetch("violating")
    refute_empty violating

    violating.each do |relative|
      path = File.join(FIXTURE_DIR, relative)
      assert_operator rubocop_offense_count(path), :>=, 1,
                      "Expected offense on #{relative}"
    end
  end

  def test_clean_view_fixtures_are_silent
    manifest.fetch("views").fetch("clean").each do |relative|
      path = File.join(FIXTURE_DIR, relative)
      assert_equal 0, rubocop_offense_count(path),
                   "Expected no offense on #{relative}"
    end
  end

  def test_value_object_chain_in_view_does_not_fire_via_rubocop
    Dir.mktmpdir do |dir|
      view = File.join(dir, "app/views/x/show.html.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, "<%= name.upcase.strip.split(' ').first %>\n")

      assert_equal 0, rubocop_offense_count(view, force_exclusion: true)
    end
  end

  def test_control_flow_erb_tag_with_deep_chain_fires_via_rubocop
    Dir.mktmpdir do |dir|
      view = File.join(dir, "app/views/x/show.html.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, "<% if current_user.account.subscription.plan.name.present? %>\n")

      assert_operator rubocop_offense_count(view, force_exclusion: true), :>=, 1
    end
  end

  def test_trim_mode_control_flow_erb_tag_with_deep_chain_fires_via_rubocop
    Dir.mktmpdir do |dir|
      view = File.join(dir, "app/views/x/show.html.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, "<%- if current_user.account.subscription.plan.name.present? %>\n")

      assert_operator rubocop_offense_count(view, force_exclusion: true), :>=, 1
    end
  end

  def test_control_flow_erb_tag_does_not_emit_synthetic_core_offenses
    Dir.mktmpdir do |dir|
      view = File.join(dir, "app/views/x/show.html.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, "<% if current_user.account.subscription.plan.name.present? %>\n")

      assert_empty non_metz_offenses(view)
    end
  end

  def test_erb_outside_app_views_does_not_fire_via_rubocop
    Dir.mktmpdir do |dir|
      view = File.join(dir, "lib/template.erb")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, "<%= a.b.c.d.e.f %>\n")

      assert_equal 0, rubocop_offense_count(view)
    end
  end

  def test_violating_haml_fixture_fires_via_rubocop
    assert_operator install_fixture_offense_count("violating.html.haml"), :>=, 1
  end

  def test_clean_haml_fixture_is_silent_via_rubocop
    assert_equal 0, install_fixture_offense_count("clean.html.haml")
  end

  def test_violating_slim_fixture_fires_via_rubocop
    assert_operator install_fixture_offense_count("violating.html.slim"), :>=, 1
  end

  def test_clean_slim_fixture_is_silent_via_rubocop
    assert_equal 0, install_fixture_offense_count("clean.html.slim")
  end

  def test_haml_outside_app_views_does_not_fire_via_rubocop
    assert_equal 0, install_fixture_offense_count("violating.html.haml",
                                                  install_at: "lib/template.haml")
  end

  def test_slim_outside_app_views_does_not_fire_via_rubocop
    assert_equal 0, install_fixture_offense_count("violating.html.slim",
                                                  install_at: "lib/template.slim")
  end

  private

  def install_fixture_offense_count(fixture_name, install_at: nil)
    Dir.mktmpdir do |dir|
      ext = File.extname(fixture_name)
      install_at ||= "app/views/x/show.html#{ext}"
      dest = File.join(dir, install_at)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(view_fixture_path(fixture_name), dest)

      rubocop_offense_count(dest)
    end
  end

  def view_fixture_path(name)
    File.join(REPO_ROOT, "rubocop-metz/test/fixtures/views", name)
  end

  def manifest
    @manifest ||= YAML.load_file(File.join(FIXTURE_DIR, ".fixture_manifest.yml"))
  end

  def view_offenses
    Array(@metz_offenses).select { |o| o.cop_name == "Metz/ViewsDeepNavigation" }
  end

  def rubocop_offense_count(path, force_exclusion: false)
    cmd = ["bundle", "exec", "rubocop", "--plugin", "rubocop-metz",
           "--only", "Metz/ViewsDeepNavigation", "--format", "json"]
    cmd << "--force-exclusion" if force_exclusion
    cmd << path
    rubocop_offenses(cmd)
      .count { |o| o["cop_name"] == "Metz/ViewsDeepNavigation" }
  end

  def non_metz_offenses(path)
    cmd = ["bundle", "exec", "rubocop", "--plugin", "rubocop-metz",
           "--force-exclusion", "--format", "json", path]
    rubocop_offenses(cmd).reject { |o| o["cop_name"].to_s.start_with?("Metz/") }
  end

  def rubocop_offenses(cmd)
    out, = Open3.capture3(*cmd, chdir: REPO_ROOT)
    JSON.parse(out).fetch("files", []).flat_map { |f| f["offenses"] }
  end
end
