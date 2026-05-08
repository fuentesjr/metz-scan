# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "base_fixtures"

class RuboCopCopMetzBaseTest < Minitest::Test
  def test_subclass_of_rubocop_cop_base
    assert_operator RuboCop::Cop::Metz::Base, :<, RuboCop::Cop::Base
  end

  def test_includes_metadata_mixin
    assert_includes RuboCop::Cop::Metz::Base.ancestors, Metz::CopMetadata
  end

  def test_default_metadata_values
    assert_equal "", MetzBaseTestCopDefaults.why_it_matters
    assert_equal :manual, MetzBaseTestCopDefaults.fix_safety
    assert_equal [], MetzBaseTestCopDefaults.suggested_next_moves
  end

  def test_metadata_dsl_round_trip
    assert_equal(
      {
        why_it_matters: "matters",
        fix_safety: :unsafe,
        suggested_next_moves: ["extract method"]
      },
      MetzBaseTestCopMetadata.metz_metadata
    )
  end

  def test_on_send_definition_aliases_on_csend
    assert_includes MetzBaseTestCopOnSend.instance_methods(false), :on_csend
    assert_equal(
      MetzBaseTestCopOnSend.instance_method(:on_send),
      MetzBaseTestCopOnSend.instance_method(:on_csend)
    )
  end
end
