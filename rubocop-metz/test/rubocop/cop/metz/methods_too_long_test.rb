# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzMethodsTooLongTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    RuboCop::Cop::Metz::MethodsTooLong
  end

  def cop_config
    {
      "Max" => 5,
      "CountComments" => false,
      "CountAsOne" => [],
      "AllowedMethods" => [],
      "AllowedPatterns" => []
    }
  end

  def test_registered_in_global_registry
    assert_equal(
      RuboCop::Cop::Metz::MethodsTooLong,
      RuboCop::Cop::Registry.global.find_by_cop_name("Metz/MethodsTooLong")
    )
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::MethodsTooLong.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_fires_on_method_with_seven_line_body
    body = %w[a b c d e f g].map { |n| "#{n} = 1" }.join("\n")
    source = "def big\n#{body}\nend\n"

    assert_metz_offense_count(1, source)
    assert_equal "Method `big` has too many lines. [7/5]", @metz_offenses.first.message
  end

  def test_silent_on_method_with_five_line_body
    body = %w[a b c d e].map { |n| "#{n} = 1" }.join("\n")
    source = "def ok\n#{body}\nend\n"

    refute_offense(source)
  end

  def test_silent_at_exact_max_boundary
    body = %w[a b c d e].map { |n| "#{n} = 1" }.join("\n")

    refute_offense("def boundary\n#{body}\nend\n")
  end

  def test_fires_just_above_boundary
    body = %w[a b c d e f].map { |n| "#{n} = 1" }.join("\n")

    assert_metz_offense_count(1, "def just_over\n#{body}\nend\n")
  end

  def test_fires_on_singleton_method
    body = %w[a b c d e f g].map { |n| "#{n} = 1" }.join("\n")

    assert_metz_offense_count(1, "def self.big\n#{body}\nend\n")
    assert_equal "Method `self.big` has too many lines. [7/5]", @metz_offenses.first.message
  end

  def test_names_singleton_method_on_a_constant
    body = "  step\n" * 7

    assert_metz_offense_count(1, "def Foo.big\n#{body}end\n")
    assert_equal "Method `Foo.big` has too many lines. [7/5]", @metz_offenses.first.message
  end

  def test_names_define_method_with_a_symbol_literal
    assert_define_method_message(":big", "Method `big` has too many lines. [7/5]")
  end

  def test_names_define_method_with_a_string_literal
    assert_define_method_message(%("big"), "Method `big` has too many lines. [7/5]")
  end

  def test_omits_method_name_when_define_method_argument_is_dynamic
    assert_define_method_message("dynamic_name", "Method has too many lines. [7/5]")
  end

  def assert_define_method_message(argument, message)
    body = "  step\n" * 7

    assert_metz_offense_count(1, "define_method(#{argument}) do\n#{body}end\n")
    assert_equal message, @metz_offenses.first.message
  end

  def test_silent_when_comments_dominate_and_count_comments_false
    body = ((["# comment"] * 10) + (["a = 1"] * 3)).join("\n")

    refute_offense("def commenty\n#{body}\nend\n")
  end

  def assert_metz_offense_count(expected, source)
    metz_inspect(source, nil)
    actual = (@metz_offenses || []).select { |o| o.cop_name == "Metz/MethodsTooLong" }
    assert_equal expected, actual.size,
                 "Expected #{expected} Metz/MethodsTooLong offense(s), got #{actual.size}: " \
                 "#{actual.map(&:message).inspect}"
  end
end
