# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzClassesTooLongTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    RuboCop::Cop::Metz::ClassesTooLong
  end

  def cop_config
    base = { "Max" => 100, "CountComments" => false, "CountAsOne" => [] }
    base["CountComments"] = true if @custom_count_comments
    base
  end

  def test_registered_in_global_registry
    assert_equal(
      RuboCop::Cop::Metz::ClassesTooLong,
      RuboCop::Cop::Registry.global.find_by_cop_name("Metz/ClassesTooLong")
    )
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::ClassesTooLong.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[safe unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_fires_on_class_exceeding_max_lines
    body = (["nop = 1"] * 102).join("\n")
    source = "class Big\n#{body}\nend\n"

    assert_metz_offense_count(1, source)
    assert_match(%r{Class has too many lines\. \[102/100\]}, @metz_offenses.first.message)
  end

  def test_silent_on_class_with_50_lines
    body = (["nop = 1"] * 50).join("\n")

    refute_offense("class Ok\n#{body}\nend\n")
  end

  def test_silent_at_exact_max_boundary
    body = (["nop = 1"] * 100).join("\n")

    refute_offense("class Boundary\n#{body}\nend\n")
  end

  def test_fires_exactly_once_just_above_boundary
    body = (["nop = 1"] * 101).join("\n")

    assert_metz_offense_count(1, "class JustOver\n#{body}\nend\n")
  end

  def test_silent_when_comments_dominate_and_count_comments_false
    body = ((["# comment"] * 80) + (["nop = 1"] * 30)).join("\n")

    refute_offense("class WithComments\n#{body}\nend\n")
  end

  def test_fires_when_count_comments_true_and_total_lines_exceed_max
    body = ((["# comment"] * 80) + (["nop = 1"] * 30)).join("\n")
    @custom_count_comments = true

    assert_metz_offense_count(1, "class WithComments\n#{body}\nend\n")
  end

  def test_silent_on_top_level_constant_assignment
    refute_offense("FOO = 1\n")
  end

  def test_fires_on_class_new_block_assigned_to_constant
    body = (["nop = 1"] * 102).join("\n")
    source = +"Big = Class.new do\n"
    source << body
    source << "\nend\n"

    assert_metz_offense_count(1, source)
  end

  def test_fires_on_singleton_class_body_exceeding_max
    body = (["nop = 1"] * 102).join("\n")
    source = +"class << self\n"
    source << body
    source << "\nend\n"

    assert_metz_offense_count(1, source)
  end

  def assert_metz_offense_count(expected, source)
    metz_inspect(source, nil)
    actual = (@metz_offenses || []).select { |o| o.cop_name == "Metz/ClassesTooLong" }
    assert_equal expected, actual.size,
                 "Expected #{expected} Metz/ClassesTooLong offense(s), got #{actual.size}: " \
                 "#{actual.map(&:message).inspect}"
  end
end
