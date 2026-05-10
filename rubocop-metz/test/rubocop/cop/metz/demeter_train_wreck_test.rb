# frozen_string_literal: true

require_relative "../../../test_helper"

class RuboCopCopMetzDemeterTrainWreckTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    RuboCop::Cop::Metz::DemeterTrainWreck
  end

  def cop_config
    {
      "Max" => 4,
      "AllowedReceivers" => %w[Rails Arel Time Date DateTime],
      "AllowedValueObjects" => %w[String Integer Float Symbol Array Hash Set]
    }
  end

  def test_registered_in_global_registry
    assert_equal(
      RuboCop::Cop::Metz::DemeterTrainWreck,
      RuboCop::Cop::Registry.global.find_by_cop_name("Metz/DemeterTrainWreck")
    )
  end

  def test_metadata_dsl_is_populated
    meta = RuboCop::Cop::Metz::DemeterTrainWreck.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_includes %i[unsafe manual], meta[:fix_safety]
    refute_empty meta[:suggested_next_moves]
  end

  def test_metadata_mentions_demeter_or_object_graph
    meta = RuboCop::Cop::Metz::DemeterTrainWreck.metz_metadata

    assert_match(/demeter|object[\s-]?graph/i, meta[:why_it_matters])
    assert(
      meta[:suggested_next_moves].any? { |m| m.match?(/delegate|wrap/i) },
      "Expected at least one suggested next move to mention `delegate` or `wrap`."
    )
  end

  def test_responds_to_on_csend_via_base_alias
    assert_includes RuboCop::Cop::Metz::DemeterTrainWreck.instance_methods, :on_csend
    assert_equal(
      RuboCop::Cop::Metz::DemeterTrainWreck.instance_method(:on_send),
      RuboCop::Cop::Metz::DemeterTrainWreck.instance_method(:on_csend)
    )
  end

  def test_silent_on_value_object_chain
    refute_offense("def m; name.upcase.strip.split(' ').first; end\n")
  end

  def test_fires_on_object_graph_chain
    assert_demeter_offense_count(1, "def m; user.account.subscription.plan.name; end\n")
    assert_match(/Object-graph traversal of \d+ exceeds Max \(4\)/, @metz_offenses.first.message)
  end

  def test_silent_on_allowed_receiver_constant
    refute_offense("def m; Rails.application.config.action_controller.perform_caching; end\n")
  end

  def test_allowed_receiver_silences_long_chain
    refute_offense("def m; Rails.a.b.c.d.e.f; end\n")
  end

  def test_silent_on_three_hop_chain_under_max
    refute_offense("def m; account.subscription.plan.name; end\n")
  end

  def test_silent_on_trailing_value_object_method
    refute_offense("def m; account.subscription.plan.name.upcase; end\n")
  end

  def test_safe_navigation_chain_fires_identically
    assert_demeter_offense_count(1, "def m; user&.account&.subscription&.plan&.name; end\n")
  end

  def test_silent_on_arithmetic_operator_chain
    refute_offense("def m; a + b + c + d + e; end\n")
  end

  def test_silent_on_shift_operator_chain
    refute_offense("def m; a << b << c << d << e; end\n")
  end

  def test_block_body_chain_fires_independently
    source = "users.map { |u| u.account.subscription.plan.name.email }\n"

    assert_demeter_offense_count(1, source)
  end

  def test_self_receiver_chain_fires
    assert_demeter_offense_count(1, "def m; self.thing.foo.bar.baz.qux; end\n")
  end

  def test_pass_through_methods_are_transparent
    refute_offense("def m; obj.tap { _1.log }.foo.bar.itself.baz; end\n")
  end

  def test_dup_chain_with_value_objects_silent
    refute_offense("def m; name.dup.upcase.strip.first; end\n")
  end

  def test_unknown_methods_chain_fires
    assert_demeter_offense_count(1, "def m; obj.unknown_method.another.third.fourth.fifth; end\n")
  end

  def test_setter_method_does_not_fire
    refute_offense("def m; obj.foo.bar.baz.qux = value; end\n")
  end

  def test_csend_and_dot_produce_equal_offense_count
    dot_source = "def m; user.account.subscription.plan.name; end\n"
    csend_source = "def m; user&.account&.subscription&.plan&.name; end\n"

    metz_inspect(dot_source, nil)
    dot_count = (@metz_offenses || []).count { |o| o.cop_name == "Metz/DemeterTrainWreck" }

    metz_inspect(csend_source, nil)
    csend_count = (@metz_offenses || []).count { |o| o.cop_name == "Metz/DemeterTrainWreck" }

    assert_equal dot_count, csend_count
    assert_equal 1, dot_count
  end

  def test_string_interpolation_inner_chain_fires
    source = +"def m; \"hello \#{user.account.subscription.plan.name}\"; end\n"

    assert_demeter_offense_count(1, source)
  end

  def test_literal_string_chain_silent
    refute_offense("def m; \"hello world\".upcase.strip.split(' ').first; end\n")
  end

  def test_assignment_target_silent
    refute_offense("def m; arr[0] = bar; end\n")
  end

  def assert_demeter_offense_count(expected, source)
    metz_inspect(source, nil)
    actual = (@metz_offenses || []).select { |o| o.cop_name == "Metz/DemeterTrainWreck" }
    assert_equal expected, actual.size,
                 "Expected #{expected} Metz/DemeterTrainWreck offense(s), got #{actual.size}: " \
                 "#{actual.map(&:message).inspect}"
  end
end
