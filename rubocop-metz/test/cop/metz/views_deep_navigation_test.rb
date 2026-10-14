# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "json"

class CopMetzViewsDeepNavigationTest < Minitest::Test
  include Metz::Test::CopHelper

  VIEW_PATH = "app/views/users/index.html.erb"
  REPO_ROOT = File.expand_path("../../../..", __dir__)
  FIXTURE_DIR = File.join(REPO_ROOT, "test/fixtures/sample_app")

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

  def test_project_allowed_receivers_is_supported_and_suppresses_its_chains
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".rubocop.yml"), <<~YAML)
        plugins:
          - rubocop-metz
        AllCops:
          NewCops: disable
          SuggestExtensions: false
          Include: ["**/*.erb"]
        Metz/ViewsDeepNavigation:
          AllowedReceivers: [Current]
      YAML
      FileUtils.mkdir_p(File.join(dir, "app/views/x"))
      File.write(File.join(dir, "app/views/x/allowed.html.erb"), "<%= Current.user.account.owner.email %>\n")
      File.write(File.join(dir, "app/views/x/flagged.html.erb"), "<%= Session.user.account.owner.email %>\n")
      stdout, stderr, = Open3.capture3({ "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
                                       "bundle", "exec", "rubocop", "--cache", "false", "--only",
                                       "Metz/ViewsDeepNavigation", "--format", "json", "app/views", chdir: dir)
      flagged = JSON.parse(stdout).fetch("files").reject { |f| f["offenses"].empty? }.map { |f| f["path"] }

      refute_match(/does not support/, stderr)
      assert_equal ["app/views/x/flagged.html.erb"], flagged
    end
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

  def test_relevant_file_respects_cop_exclude
    config = RuboCop::Config.new(
      "Metz/ViewsDeepNavigation" => {
        "Enabled" => true,
        "MaxChainLength" => 3,
        "Exclude" => [VIEW_PATH]
      }
    )

    refute cop_class.new(config).relevant_file?(VIEW_PATH)
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

  # Every template line below holds a four-link chain; [line, column] point at its first link.
  def test_erb_output_and_control_forms_are_checked_at_template_positions
    template = <<~ERB
      <%== user.account.owner.email %>
      <%# user.account.owner.email %>
      <%%= user.account.owner.email %>
      <%= form_with(model: user.account.owner.profile) do |f| %>
      <% end %>
    ERB

    assert_equal [[1, 6], [4, 22]], template_offense_positions(template, "erb")
  end

  def test_haml_output_and_control_forms_are_checked_at_template_positions
    template = <<~HAML
      - if user.account.owner.active?
        %p hi
      != user.account.owner.email
      &= user.account.owner.email
      %p{ title: user.account.owner.name }
      %p{ title: user.account.owner.name }= user.account.owner.email
      ~ user.account.owner.email
      = form_for(user.account.owner.profile) do |f|
        = f.text_field :name
      -# user.account.owner.email
      %p user.account.owner.email
      %p= user.account.owner.email
    HAML

    assert_equal [[1, 6], [3, 4], [4, 4], [5, 12], [6, 12], [6, 39], [7, 3], [8, 12], [12, 5]],
                 template_offense_positions(template, "haml")
  end

  def test_haml_output_after_attribute_groups_is_checked_at_template_positions
    template = <<~HAML
      %div[@user]= user.account.owner.email
      %p{ title: 1 }(data-x="y")= user.account.owner.email
    HAML

    assert_equal [[1, 14], [2, 29]], template_offense_positions(template, "haml")
  end

  def test_slim_output_and_control_forms_are_checked_at_template_positions
    template = <<~SLIM
      p = user.account.owner.name
      - if user.account.owner.active?
        | hi
      p title=user.account.owner.name
      a.link[href=user.account.owner.url] = user.name
      p.note = user.account.owner.name
      = form_for(user.account.owner.profile) do |f|
        = f.text_field :name
      p title="user.account.owner.name" user.account.owner.name
      / user.account.owner.email
      | user.account.owner.email
      == user.account.owner.email
    SLIM

    assert_equal [[1, 5], [2, 6], [4, 9], [5, 13], [6, 10], [7, 12], [12, 4]],
                 template_offense_positions(template, "slim")
  end

  def test_erb_block_openers_do_not_crash_stock_layout_cops
    form = "<p>\n  <%= form_with(model: user) do |f| %>\n  <% end %>\n</p>\n"
    each = "<ul>\n  <% items.each do |i| %>\n  <% end %>\n</ul>\n"
    _, stderr, status = run_rubocop_on_views({ "form.html.erb" => form, "each.html.erb" => each },
                                             "--only", "Layout/CommentIndentation")

    refute_match(/error occurred/, stderr)
    assert status.success?, "Expected exit 0, got #{status.exitstatus}; stderr:\n#{stderr}"
  end

  # Only the `ruby` filter holds Ruby; other filter bodies are skipped whole.
  def test_only_ruby_filter_bodies_are_checked
    slim = "javascript:\n  this.owner = window.a.b.c.d.e;\nmarkdown:\n  item = a.b.c.d.e\n" \
           "ruby:\n  user.account.owner.name\n"
    haml = ":css\n  .foo{color:red}\n:ruby\n  user.account.owner.name\n"
    stdout, = run_rubocop_on_views({ "f.html.slim" => slim, "f.html.haml" => haml }, "--format", "json")
    found = JSON.parse(stdout).fetch("files").flat_map do |file|
      file["offenses"].map { |o| [File.extname(file["path"]), o["location"]["start_line"], o["cop_name"]] }
    end

    assert_equal [[".haml", 4], [".slim", 6]], found.map { |ext, line, _| [ext, line] }.uniq.sort,
                 "Only the ruby filter bodies may carry findings: #{found.inspect}"
    assert_includes found, [".haml", 4, "Metz/ViewsDeepNavigation"]
    assert_includes found, [".slim", 6, "Metz/ViewsDeepNavigation"]
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
           "--cache", "false", "--only", "Metz/ViewsDeepNavigation", "--format", "json"]
    cmd << "--force-exclusion" if force_exclusion
    cmd << path
    rubocop_offenses(cmd)
      .count { |o| o["cop_name"] == "Metz/ViewsDeepNavigation" }
  end

  def template_offense_positions(template, ext)
    Dir.mktmpdir do |dir|
      view = File.join(dir, "app/views/x/show.html.#{ext}")
      FileUtils.mkdir_p(File.dirname(view))
      File.write(view, template)
      cmd = ["bundle", "exec", "rubocop", "--plugin", "rubocop-metz", "--cache", "false",
             "--only", "Metz/ViewsDeepNavigation", "--format", "json", view]
      rubocop_offenses(cmd).map { |o| o["location"].values_at("start_line", "start_column") }.sort
    end
  end

  def run_rubocop_on_views(templates, *flags)
    Dir.mktmpdir do |dir|
      views = templates.map do |name, template|
        File.join(dir, "app/views/x", name).tap do |view|
          FileUtils.mkdir_p(File.dirname(view))
          File.write(view, template)
        end
      end
      Open3.capture3("bundle", "exec", "rubocop", "--plugin", "rubocop-metz", "--cache", "false",
                     *flags, *views, chdir: REPO_ROOT)
    end
  end

  def non_metz_offenses(path)
    cmd = ["bundle", "exec", "rubocop", "--plugin", "rubocop-metz",
           "--cache", "false", "--force-exclusion", "--format", "json", path]
    rubocop_offenses(cmd).reject { |o| o["cop_name"].to_s.start_with?("Metz/") }
  end

  def rubocop_offenses(cmd)
    out, = Open3.capture3(*cmd, chdir: REPO_ROOT)
    JSON.parse(out).fetch("files", []).flat_map { |f| f["offenses"] }
  end
end
