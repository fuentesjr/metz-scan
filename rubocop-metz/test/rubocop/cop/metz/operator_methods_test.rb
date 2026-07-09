# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzOperatorMethodsTest < Minitest::Test
  def operator_methods
    RuboCop::Cop::Metz::OperatorMethods
  end

  def test_operator_methods_true_for_arithmetic
    assert operator_methods.operator?(:+)
    assert operator_methods.operator?(:-)
    assert operator_methods.operator?(:*)
    assert operator_methods.operator?(:/)
    assert operator_methods.operator?(:%)
    assert operator_methods.operator?(:**)
  end

  def test_operator_methods_true_for_comparison
    assert operator_methods.operator?(:<)
    assert operator_methods.operator?(:>)
    assert operator_methods.operator?(:<=)
    assert operator_methods.operator?(:>=)
    assert operator_methods.operator?(:<=>)
  end

  def test_operator_methods_true_for_equality
    assert operator_methods.operator?(:==)
    assert operator_methods.operator?(:!=)
    assert operator_methods.operator?(:===)
  end

  def test_operator_methods_true_for_bitwise
    assert operator_methods.operator?(:&)
    assert operator_methods.operator?(:|)
    assert operator_methods.operator?(:^)
    assert operator_methods.operator?(:<<)
    assert operator_methods.operator?(:>>)
  end

  def test_operator_methods_true_for_pattern_matching
    assert operator_methods.operator?(:=~)
    assert operator_methods.operator?(:!~)
  end

  def test_operator_methods_false_for_regular_methods
    refute operator_methods.operator?(:to_s)
    refute operator_methods.operator?(:call)
    refute operator_methods.operator?(:foo)
    refute operator_methods.operator?(:upcase)
  end
end
