# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "base_fixtures"

class RuboCopCopMetzBaseTest < Minitest::Test
  FIRST_PARTY_COPS = [
    RuboCop::Cop::Metz::ClassesTooLong,
    RuboCop::Cop::Metz::ControllersTooManyDirectCollaborators,
    RuboCop::Cop::Metz::DemeterTrainWreck,
    RuboCop::Cop::Metz::MethodsTooLong,
    RuboCop::Cop::Metz::MethodsTooManyParameters
  ].freeze

  def test_subclass_of_rubocop_cop_base
    assert_operator RuboCop::Cop::Metz::Base, :<, RuboCop::Cop::Base
  end

  def test_compatibility_shim_includes_metadata_mixin
    assert_includes RuboCop::Cop::Metz::Base.ancestors, Metz::CopMetadata
  end

  def test_first_party_cops_do_not_inherit_from_local_base
    FIRST_PARTY_COPS.each do |cop|
      assert_equal RuboCop::Cop::Base, cop.superclass, "#{cop} should compose Metz helpers explicitly"
      refute_operator cop, :<, RuboCop::Cop::Metz::Base
    end
  end

  def test_first_party_cops_expose_metadata
    FIRST_PARTY_COPS.each do |cop|
      refute_empty cop.why_it_matters
      assert_includes %i[manual unsafe], cop.fix_safety
      refute_empty cop.suggested_next_moves
    end
  end

  def test_compatibility_shim_exposes_metadata_dsl
    assert_equal(
      {
        why_it_matters: "compatibility matters",
        fix_safety: :unsafe,
        suggested_next_moves: ["keep downstream custom cops working"]
      },
      MetzBaseCompatibilityTestCop.metz_metadata
    )
  end

  def test_compatibility_shim_aliases_on_send_definitions_to_on_csend
    assert_includes MetzBaseCompatibilityTestCop.instance_methods(false), :on_csend
    assert_equal(
      MetzBaseCompatibilityTestCop.instance_method(:on_send),
      MetzBaseCompatibilityTestCop.instance_method(:on_csend)
    )
  end
end
