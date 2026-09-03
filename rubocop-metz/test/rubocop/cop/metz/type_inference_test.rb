# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzTypeInferenceTest < Minitest::Test
  def inference
    RuboCop::Cop::Metz::DemeterTrainWreck::TypeInference
  end

  def test_next_type_reports_known_method_result
    assert_equal :string, inference.next_type(:string, :upcase)
    assert_equal :array, inference.next_type(:string, :split)
  end

  def test_next_type_returns_nil_for_unmapped_method_or_type
    assert_nil inference.next_type(:string, :non_existent)
    assert_nil inference.next_type(:undefined_type, :to_s)
  end

  def test_reverse_lookup_returns_unknown_on_collisions
    assert_equal :unknown, inference.reverse_lookup(:upcase)
  end

  def test_reverse_lookup_preserves_non_colliding_return
    assert_equal :integer, inference.reverse_lookup(:size)
  end

  def test_reverse_lookup_is_nil_for_unknown_method
    assert_nil inference.reverse_lookup(:non_existent)
  end

  def test_literal_type_maps_literal_nodes
    literal_node = Struct.new(:type)
    assert_equal :string, inference.literal_type(literal_node.new(:str))
    assert_equal :array, inference.literal_type(literal_node.new(:array))
    # rubocop:disable-next Lint/BooleanSymbol
    assert_equal :boolean, inference.literal_type(literal_node.new(:true))
  end

  def test_literal_type_returns_nil_for_unknown_node_type
    literal_node = Struct.new(:type)

    assert_nil inference.literal_type(literal_node.new(:send))
  end

  def test_pass_through_methods
    assert inference.pass_through?(:freeze)
    assert inference.pass_through?(:itself)
    refute inference.pass_through?(:non_existent)
  end

  def test_operator_methods
    assert inference.operator?(:+)
    assert inference.operator?(:<)
    assert inference.operator?(:&)
    refute inference.operator?(:to_s)
  end

  def test_mapped_methods_exist_on_expected_core_classes
    mapping = {
      string: String,
      symbol: Symbol,
      integer: Integer,
      float: Float,
      array: Array,
      hash: Hash,
      boolean: [TrueClass, FalseClass],
      regexp: Regexp,
      range: Range,
      nil_value: NilClass,
      enumerator: Enumerator,
      proc: Proc,
      set: Set
    }.freeze

    unverifiable = {
      hash: [:keys_at],
      range: [:to_ary],
      set: [:to_ary]
    }.freeze

    missing = []
    inference::METHOD_RETURN_TYPES.each do |type, methods|
      core_classes = Array(mapping.fetch(type))
      methods.each_key do |method_name|
        next unless method_name.is_a?(Symbol)
        next if unverifiable.fetch(type, []).include?(method_name)

        present = core_classes.any? do |klass|
          klass.method_defined?(method_name)
        end
        missing << [type, method_name] unless present
      end
    end

    assert_empty(
      missing,
      "Expected all mapped methods to exist on their associated Ruby core class(es): #{missing.join(', ')}"
    )
  end
end
