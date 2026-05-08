# frozen_string_literal: true

require_relative "../test_helper"

class MetzCopMetadataTest < Minitest::Test
  def test_resolves_to_a_module
    assert_kind_of Module, Metz::CopMetadata
    refute_kind_of Class, Metz::CopMetadata
  end

  def test_include_exposes_class_level_setter_macros
    klass = Class.new { include Metz::CopMetadata }

    %i[why_it_matters fix_safety suggested_next_moves].each do |macro|
      assert_respond_to klass, macro, "expected class-level macro #{macro}"
    end
  end

  def test_extend_exposes_class_level_setter_macros
    klass = Class.new { extend Metz::CopMetadata }

    %i[why_it_matters fix_safety suggested_next_moves].each do |macro|
      assert_respond_to klass, macro, "expected class-level macro #{macro}"
    end
  end

  def test_setters_persist_values_for_class_level_readers
    klass = Class.new do
      include Metz::CopMetadata

      why_it_matters "x"
      fix_safety :safe
      suggested_next_moves %w[a b]
    end

    assert_equal "x", klass.why_it_matters
    assert_equal :safe, klass.fix_safety
    assert_equal %w[a b], klass.suggested_next_moves
  end

  def test_metz_metadata_hash_aggregates_values
    klass = Class.new do
      include Metz::CopMetadata

      why_it_matters "x"
      fix_safety :safe
      suggested_next_moves %w[a b]
    end

    assert_equal(
      { why_it_matters: "x", fix_safety: :safe, suggested_next_moves: %w[a b] },
      klass.metz_metadata
    )
  end

  def test_defaults_when_no_setters_invoked
    klass = Class.new { include Metz::CopMetadata }

    assert_equal "", klass.why_it_matters
    assert_equal :manual, klass.fix_safety
    assert_equal [], klass.suggested_next_moves
    assert_equal(
      { why_it_matters: "", fix_safety: :manual, suggested_next_moves: [] },
      klass.metz_metadata
    )
  end

  def test_subclasses_do_not_leak_metadata_from_parent_unless_set
    parent = Class.new do
      include Metz::CopMetadata

      why_it_matters "p"
      fix_safety :unsafe
      suggested_next_moves ["m"]
    end
    child = Class.new(parent)

    assert_equal "", child.why_it_matters
    assert_equal :manual, child.fix_safety
    assert_equal [], child.suggested_next_moves
  end

  def test_introspection_methods_are_public
    klass = Class.new { include Metz::CopMetadata }
    public_methods = klass.public_methods

    assert_includes public_methods, :why_it_matters
    assert_includes public_methods, :fix_safety
    assert_includes public_methods, :suggested_next_moves
    assert_includes public_methods, :metz_metadata
  end
end
