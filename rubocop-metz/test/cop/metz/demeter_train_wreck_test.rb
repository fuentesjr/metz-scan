# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzDemeterTrainWreckTest < Minitest::Test
  include Metz::Test::CopHelper

  FIXTURE_DIR = File.expand_path("../../fixtures/demeter", __dir__)
  CANONICAL_FIXTURES = %w[
    name_upcase_strip.rb
    user_account_chain.rb
    rails_app_config.rb
    csend_chain.rb
    operator_chain.rb
  ].freeze

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

  def test_canonical_fixtures_are_vendored_under_test_fixtures_demeter
    CANONICAL_FIXTURES.each do |basename|
      path = File.join(FIXTURE_DIR, basename)
      assert File.file?(path), "Expected canonical fixture at #{path}"
    end
  end

  def test_value_object_chain_fixture_is_silent
    refute_offense(read_fixture("name_upcase_strip.rb"))
  end

  def test_object_graph_fixture_fires_one_offense
    metz_inspect(read_fixture("user_account_chain.rb"), nil)

    offenses = demeter_offenses
    assert_equal 1, offenses.size,
                 "Expected exactly one Metz/DemeterTrainWreck offense for user_account_chain.rb, " \
                 "got #{offenses.size}: #{offenses.map(&:message).inspect}"
  end

  def test_rails_allowed_receiver_fixture_is_silent
    refute_offense(read_fixture("rails_app_config.rb"))
  end

  def test_csend_chain_fixture_fires_like_dot_chain
    metz_inspect(read_fixture("csend_chain.rb"), nil)

    assert_equal 1, demeter_offenses.size,
                 "Expected csend_chain.rb to fire exactly one offense (csend treated like dot)."
  end

  def test_operator_chain_fixture_is_silent
    refute_offense(read_fixture("operator_chain.rb"))
  end

  def test_metadata_mentions_demeter_or_object_graph
    meta = RuboCop::Cop::Metz::DemeterTrainWreck.metz_metadata

    assert_match(
      /demeter|object[\s-]?graph/i,
      meta[:why_it_matters],
      "why_it_matters must mention Demeter or object graph"
    )
  end

  def test_metadata_suggests_delegate_or_wrap
    meta = RuboCop::Cop::Metz::DemeterTrainWreck.metz_metadata

    assert(
      meta[:suggested_next_moves].any? { |move| move.match?(/delegate|wrap/i) },
      "suggested_next_moves must contain at least one entry mentioning `delegate` or `wrap`, " \
      "got: #{meta[:suggested_next_moves].inspect}"
    )
  end

  def test_metadata_fix_safety_is_unsafe_or_manual
    assert_includes %i[unsafe manual],
                    RuboCop::Cop::Metz::DemeterTrainWreck.metz_metadata[:fix_safety]
  end

  private

  def read_fixture(basename)
    File.read(File.join(FIXTURE_DIR, basename))
  end

  def demeter_offenses
    Array(@metz_offenses).select { |o| o.cop_name == "Metz/DemeterTrainWreck" }
  end
end
