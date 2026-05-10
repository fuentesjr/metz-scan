# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class M3DemeterSeverityExcludeIntegrationTest < Minitest::Test
  REPO_ROOT = File.expand_path("../../..", __dir__)
  GRAPH_VIOLATION = "def m; user.account.subscription.plan.name; end\n"

  def test_severity_refactor_sits_below_convention_fail_level
    in_tmp_fixture(GRAPH_VIOLATION) do |path|
      _, _, status = run_rubocop("--fail-level", "convention", path)

      assert status.success?,
             "Refactor-severity offense must not surface under --fail-level convention"
    end
  end

  def test_fail_level_refactor_surfaces_offense_as_non_zero
    in_tmp_fixture(GRAPH_VIOLATION) do |path|
      _, _, status = run_rubocop("--fail-level", "refactor", path)

      refute status.success?,
             "--fail-level refactor must surface a refactor-severity offense as non-zero"
    end
  end

  def test_fail_level_warning_does_not_surface_refactor_offense
    in_tmp_fixture(GRAPH_VIOLATION) do |path|
      _, _, status = run_rubocop("--fail-level", "warning", path)

      assert status.success?,
             "--fail-level warning must NOT surface a refactor-severity offense"
    end
  end

  def test_exclude_glob_silences_spec_paths_and_keeps_lib_paths_loud
    Dir.mktmpdir("metz-dt-paths") do |dir|
      stage_host_project(dir)

      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
        "bundle", "exec", "rubocop",
        "--only", "Metz/DemeterTrainWreck",
        "--format", "json",
        chdir: dir
      )

      assert json_payload?(stdout),
             "Expected JSON on stdout but got status=#{status.exitstatus}, stderr:\n#{stderr}"

      counts = offense_counts_by_path(stdout)

      assert_equal 1, counts.fetch("lib/violator.rb"),
                   "Expected lib/violator.rb to fire one Demeter offense"
      assert_equal 0, counts.fetch("spec/violator_spec.rb"),
                   "Expected spec/violator_spec.rb to be silenced by Exclude"
    end
  end

  private

  def in_tmp_fixture(body)
    Dir.mktmpdir("metz-dt-fixture") do |dir|
      path = File.join(dir, "fixture.rb")
      File.write(path, body)
      yield path
    end
  end

  def run_rubocop(*flags)
    Open3.capture3(
      { "BUNDLE_GEMFILE" => File.join(REPO_ROOT, "Gemfile") },
      "bundle", "exec", "rubocop",
      "--plugin", "rubocop-metz",
      "--only", "Metz/DemeterTrainWreck",
      *flags,
      chdir: REPO_ROOT
    )
  end

  def stage_host_project(dir)
    FileUtils.mkdir_p(File.join(dir, "lib"))
    FileUtils.mkdir_p(File.join(dir, "spec"))
    File.write(File.join(dir, "lib/violator.rb"), GRAPH_VIOLATION)
    File.write(File.join(dir, "spec/violator_spec.rb"), GRAPH_VIOLATION)
    File.write(File.join(dir, ".rubocop.yml"), <<~YAML)
      inherit_gem:
        rubocop-metz: config/default.yml
      plugins:
        - rubocop-metz
      AllCops:
        NewCops: disable
        SuggestExtensions: false
    YAML
  end

  def json_payload?(stdout)
    JSON.parse(stdout)
    true
  rescue JSON::ParserError
    false
  end

  def offense_counts_by_path(stdout)
    payload = JSON.parse(stdout)
    payload.fetch("files").each_with_object({}) do |file, acc|
      relevant = file["offenses"].count { |o| o["cop_name"] == "Metz/DemeterTrainWreck" }
      acc[file["path"]] = relevant
    end
  end
end
