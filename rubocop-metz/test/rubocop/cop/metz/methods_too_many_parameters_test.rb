# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzMethodsTooManyParametersTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    RuboCop::Cop::Metz::MethodsTooManyParameters
  end

  def cop_config
    { "Max" => 4 }
  end

  def test_registered_in_global_registry
    assert_equal(
      RuboCop::Cop::Metz::MethodsTooManyParameters,
      RuboCop::Cop::Registry.global.find_by_cop_name("Metz/MethodsTooManyParameters")
    )
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::MethodsTooManyParameters.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_fires_on_method_with_five_parameters
    assert_metz_offense_count(1, "def big(a, b, c, d, e); end\n")
    assert_match(%r{Avoid parameter lists longer than 4 parameters\. \[5/4\]}, @metz_offenses.first.message)
  end

  def test_silent_on_method_with_four_parameters
    refute_offense("def ok(a, b, c, d); end\n")
  end

  def test_silent_at_exact_max_boundary
    refute_offense("def boundary(a, b, c, d); end\n")
  end

  def test_silent_on_zero_argument_method
    refute_offense("def none; end\n")
  end

  def test_fires_on_mixed_six_parameter_method
    assert_metz_offense_count(1, "def mix(a, b = 1, *c, d:, e: 2, **f); end\n")
    assert_match(%r{\[6/4\]}, @metz_offenses.first.message)
  end

  def test_silent_on_mixed_four_parameter_method
    refute_offense("def mix_ok(a, b = 1, c:, d: 2); end\n")
  end

  def test_block_argument_is_not_counted
    refute_offense("def with_block(a, b, c, d, &blk); end\n")
  end

  def test_fires_on_singleton_method_with_five_parameters
    assert_metz_offense_count(1, "def self.big(a, b, c, d, e); end\n")
  end

  def assert_metz_offense_count(expected, source)
    metz_inspect(source, nil)
    actual = (@metz_offenses || []).select { |o| o.cop_name == "Metz/MethodsTooManyParameters" }
    assert_equal expected, actual.size,
                 "Expected #{expected} Metz/MethodsTooManyParameters offense(s), got #{actual.size}: " \
                 "#{actual.map(&:message).inspect}"
  end
end
