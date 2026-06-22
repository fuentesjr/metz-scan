# frozen_string_literal: true

require_relative "../test_helper"

class ThresholdCopsIntegrationTest < Minitest::Test
  COP_CLASSES = [
    RuboCop::Cop::Metz::ClassesTooLong,
    RuboCop::Cop::Metz::MethodsTooLong,
    RuboCop::Cop::Metz::MethodsTooManyParameters
  ].freeze

  COP_NAMES = COP_CLASSES.map(&:cop_name).freeze

  def test_all_three_cops_carry_populated_metadata
    COP_CLASSES.each do |klass|
      meta = klass.metz_metadata

      refute_empty meta[:why_it_matters],
                   "#{klass.cop_name} why_it_matters must be non-empty"
      assert_includes %i[safe unsafe manual], meta[:fix_safety],
                      "#{klass.cop_name} fix_safety must be in [:safe, :unsafe, :manual]"
      refute_empty meta[:suggested_next_moves],
                   "#{klass.cop_name} suggested_next_moves must be non-empty"
    end
  end

  def test_combined_fixture_emits_exactly_one_offense_per_cop
    offenses = run_team_against(combined_fixture_source)

    assert_equal COP_NAMES.sort, offenses.map(&:cop_name).sort,
                 "Combined fixture should produce one offense per threshold cop, got: " \
                 "#{offenses.map(&:cop_name).inspect}"
  end

  private

  def combined_fixture_source
    body_lines = (1..102).map { |i| "  nop_#{i} = 1" }
    <<~RUBY
      class Combo
        def big_method
          a = 1
          b = 1
          c = 1
          d = 1
          e = 1
          f = 1
          g = 1
        end

        def with_many_params(a, b, c, d, e)
          a + b + c + d + e
        end

      #{body_lines.join("\n")}
      end
    RUBY
  end

  def run_team_against(source)
    config = RuboCop::Config.new(
      "Metz/ClassesTooLong" => { "Enabled" => true, "Max" => 100,
                                 "CountComments" => false, "CountAsOne" => [] },
      "Metz/MethodsTooLong" => { "Enabled" => true, "Max" => 5,
                                 "CountComments" => false, "CountAsOne" => [],
                                 "AllowedMethods" => [], "AllowedPatterns" => [] },
      "Metz/MethodsTooManyParameters" => { "Enabled" => true, "Max" => 4 }
    )
    cops = COP_CLASSES.map { |k| k.new(config) }
    processed = RuboCop::ProcessedSource.new(source, 3.3)
    processed.config = config
    processed.registry = RuboCop::Cop::Registry.new(COP_CLASSES)

    team = RuboCop::Cop::Team.new(cops, config, raise_error: true)
    team.investigate(processed).offenses.reject(&:disabled?)
  end
end
