# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "stringio"

module ::RuboCop
  module Cop
    module Metz
      class MetadataLessProbe < ::RuboCop::Cop::Base
        MSG = "metadata-less probe"
      end
    end
  end
end

class MetzJsonFormatterMissingMetadataTest < Minitest::Test
  COP_CLASS = ::RuboCop::Cop::Metz::MetadataLessProbe
  COP_NAME = COP_CLASS.cop_name

  def setup
    @cop_class = COP_CLASS
    RuboCop::Cop::Registry.global.enlist(@cop_class) unless RuboCop::Cop::Registry.global.find_by_cop_name(COP_NAME)
  end

  def test_metz_cop_class_without_metadata_dsl_is_not_enriched_with_dsl
    refute_respond_to @cop_class, :metz_metadata,
                      "Probe cop must NOT include Metz::CopMetadata for this regression"
  end

  def test_hash_for_offense_returns_nil_defaults_for_metadataless_metz_cop
    hash = formatter.hash_for_offense(build_offense(cop_name: COP_NAME))

    assert hash.key?(:why_it_matters), "Expected :why_it_matters key on Metz offense"
    assert hash.key?(:fix_safety), "Expected :fix_safety key on Metz offense"
    assert hash.key?(:suggested_next_moves), "Expected :suggested_next_moves key on Metz offense"

    assert_nil hash[:why_it_matters], "Metadata-less cop should yield nil why_it_matters"
    assert_nil hash[:fix_safety], "Metadata-less cop should yield nil fix_safety"
    assert_equal [], hash[:suggested_next_moves],
                 "Metadata-less cop should yield empty suggested_next_moves array"
  end

  def test_full_output_remains_valid_json_with_standard_top_level_shape
    output = StringIO.new
    fmt = RuboCop::Formatter::MetzJsonFormatter.new(output)
    fixture_path = "/tmp/metz-missing-metadata-probe.rb"
    File.write(fixture_path, "def f; end\n")

    fmt.started([fixture_path])
    fmt.file_finished(fixture_path, [build_offense(cop_name: COP_NAME)])
    fmt.finished([fixture_path])

    parsed = JSON.parse(output.string)
    assert parsed.key?("metadata"), "Top-level :metadata missing"
    assert parsed.key?("files"), "Top-level :files missing"
    assert parsed.key?("summary"), "Top-level :summary missing"
    %w[offense_count target_file_count inspected_file_count].each do |key|
      assert parsed["summary"].key?(key), "Summary missing #{key.inspect}"
    end

    offense = parsed.dig("files", 0, "offenses", 0)
    assert_nil offense["why_it_matters"]
    assert_nil offense["fix_safety"]
    assert_equal [], offense["suggested_next_moves"]
  ensure
    File.delete(fixture_path) if fixture_path && File.exist?(fixture_path)
  end

  def test_non_metz_offense_is_not_enriched_even_when_class_is_metadataless
    hash = formatter.hash_for_offense(build_offense(cop_name: "Style/IfUnlessModifier"))

    refute hash.key?(:why_it_matters), "Non-Metz offense must not carry :why_it_matters"
    refute hash.key?(:fix_safety), "Non-Metz offense must not carry :fix_safety"
    refute hash.key?(:suggested_next_moves), "Non-Metz offense must not carry :suggested_next_moves"
  end

  private

  def formatter
    @formatter ||= RuboCop::Formatter::MetzJsonFormatter.new(StringIO.new)
  end

  def build_offense(cop_name:)
    source = RuboCop::ProcessedSource.new("def f\nend\n", 3.3)
    range = Parser::Source::Range.new(source.buffer, 0, 5)
    RuboCop::Cop::Offense.new(:convention, range, "probe message", cop_name, :uncorrected)
  end
end
