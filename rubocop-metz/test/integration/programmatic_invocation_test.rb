# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "stringio"

class ProgrammaticInvocationTest < Minitest::Test
  FIXTURE_PATH = File.expand_path("../fixtures/metz_offender.rb", __dir__)

  def test_programmatic_plugin_invocation_emits_enriched_metz_offenses
    parsed = run_cli_and_parse([
                                 "--plugin", "rubocop-metz",
                                 "--format", "RuboCop::Formatter::MetzJsonFormatter",
                                 FIXTURE_PATH
                               ])

    assert_standard_top_level_shape(parsed)

    metz_offenses = collect_metz_offenses(parsed)
    refute_empty metz_offenses,
                 "Expected at least one Metz/* offense from #{FIXTURE_PATH}"
    assert metz_offenses.any? { |o| o["cop_name"].start_with?("Metz/") && o.key?("why_it_matters") },
           "VAL-M5-008: programmatic invocation must yield at least one Metz offense with why_it_matters"

    assert_enriched_metz_offenses(metz_offenses)
  end

  def test_programmatic_legacy_require_invocation_emits_enriched_metz_offenses
    parsed = run_cli_and_parse([
                                 "--require", "rubocop-metz",
                                 "--format", "RuboCop::Formatter::MetzJsonFormatter",
                                 FIXTURE_PATH
                               ])

    assert_standard_top_level_shape(parsed)

    metz_offenses = collect_metz_offenses(parsed)
    refute_empty metz_offenses,
                 "VAL-M5-007: legacy --require path must still produce Metz offenses"
    assert_enriched_metz_offenses(metz_offenses)
  end

  def test_programmatic_plugin_and_legacy_require_produce_identical_offense_set
    plugin_run = run_cli_and_parse([
                                     "--plugin", "rubocop-metz",
                                     "--format", "RuboCop::Formatter::MetzJsonFormatter",
                                     FIXTURE_PATH
                                   ])
    require_run = run_cli_and_parse([
                                      "--require", "rubocop-metz",
                                      "--format", "RuboCop::Formatter::MetzJsonFormatter",
                                      FIXTURE_PATH
                                    ])

    assert_equal offense_signature(plugin_run), offense_signature(require_run),
                 "Plugin-loaded and --require-loaded paths should yield the same offense set"
  end

  private

  def run_cli_and_parse(argv)
    raw = capture_stdout do
      exit_code = RuboCop::CLI.new.run(argv)
      refute_equal 2, exit_code,
                   "RuboCop::CLI reported an internal error (exit 2) for argv=#{argv.inspect}"
    end

    JSON.parse(raw)
  rescue JSON::ParserError => e
    flunk "RuboCop::CLI output was not valid JSON for argv=#{argv.inspect}: #{e.message}\n" \
          "raw=#{raw.inspect}"
  end

  def collect_metz_offenses(parsed)
    Array(parsed["files"])
      .flat_map { |f| Array(f["offenses"]) }
      .select { |o| o["cop_name"].to_s.start_with?("Metz/") }
  end

  def assert_standard_top_level_shape(parsed)
    %w[metadata files summary].each do |key|
      assert parsed.key?(key), "Top-level JSON missing #{key.inspect}: #{parsed.keys.inspect}"
    end
    %w[offense_count target_file_count inspected_file_count].each do |key|
      assert parsed["summary"].key?(key), "summary missing #{key.inspect}"
    end
  end

  def assert_enriched_metz_offenses(metz_offenses)
    metz_offenses.each do |off|
      cop = off["cop_name"]
      assert off.key?("why_it_matters"), "#{cop} missing :why_it_matters"
      assert off.key?("fix_safety"), "#{cop} missing :fix_safety"
      assert off.key?("suggested_next_moves"), "#{cop} missing :suggested_next_moves"
      assert_instance_of String, off["why_it_matters"], "#{cop} why_it_matters is not a String"
      assert %w[safe unsafe manual].include?(off["fix_safety"]),
             "#{cop} fix_safety must be one of safe/unsafe/manual, got #{off['fix_safety'].inspect}"
      assert_instance_of Array, off["suggested_next_moves"],
                         "#{cop} suggested_next_moves must be an Array"
    end
  end

  def offense_signature(parsed)
    collect_metz_offenses(parsed).map do |o|
      [o["cop_name"], o.dig("location", "start_line"), o.dig("location", "start_column")]
    end.sort
  end

  def capture_stdout
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
