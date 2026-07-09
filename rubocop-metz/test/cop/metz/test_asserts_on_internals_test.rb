# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzTestAssertsOnInternalsTest < Minitest::Test
  include Metz::Test::CopHelper

  FIXTURE_DIR = File.expand_path("../../fixtures/test_asserts_on_internals", __dir__)
  MESSAGE = "Test asserts on internal state via `%<method>s`; assert on observable " \
            "behavior through the public interface instead."
  CANONICAL_FIXTURES = %w[
    minitest_instance_variable_get_test.rb
    dynamic_instance_variable_get_test.rb
    minitest_instance_variable_set_test.rb
    rspec_instance_variable_get_spec.rb
    minitest_assigns_test.rb
    assigns_string_test.rb
    rspec_assigns_spec.rb
    bare_ivar_test.rb
    assigns_receiver_test.rb
    assigns_dynamic_test.rb
    assigns_no_arg_test.rb
    csend_instance_variable_get_test.rb
    allowed_receiver_test.rb
  ].freeze

  def cop_class
    RuboCop::Cop::Metz::TestAssertsOnInternals
  end

  def cop_config
    { "AllowedReceivers" => %w[reflection_target] }
  end

  def test_canonical_fixtures_are_vendored
    CANONICAL_FIXTURES.each { |basename| assert File.file?(fixture_path(basename)) }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name("Metz/TestAssertsOnInternals")

    assert_equal RuboCop::Cop::Metz::TestAssertsOnInternals, klass
  end

  def test_default_yaml_ships_opt_in_with_test_includes
    entry = default_yml.fetch("Metz/TestAssertsOnInternals")

    assert_equal false, entry["Enabled"]
    assert_equal "refactor", entry["Severity"]
    assert_equal [], entry["AllowedReceivers"]
    assert_includes Array(entry["Include"]), "**/*_test.rb"
    assert_includes Array(entry["Include"]), "**/test_*.rb"
    assert_includes Array(entry["Include"]), "**/*_spec.rb"
  end

  def test_minitest_instance_variable_get_fires_one_offense
    assert_fixture_offense("minitest_instance_variable_get_test.rb", "instance_variable_get")
  end

  def test_dynamic_instance_variable_get_argument_still_fires
    assert_fixture_offense("dynamic_instance_variable_get_test.rb", "instance_variable_get")
  end

  def test_minitest_instance_variable_set_fires_one_offense
    assert_fixture_offense("minitest_instance_variable_set_test.rb", "instance_variable_set")
  end

  def test_rspec_instance_variable_get_fires_one_offense
    assert_fixture_offense("rspec_instance_variable_get_spec.rb", "instance_variable_get")
  end

  def test_minitest_assigns_fires_one_offense
    assert_fixture_offense("minitest_assigns_test.rb", "assigns")
  end

  def test_string_assigns_fires_one_offense
    assert_fixture_offense("assigns_string_test.rb", "assigns")
  end

  def test_rspec_assigns_fires_one_offense
    assert_fixture_offense("rspec_assigns_spec.rb", "assigns")
  end

  def test_bare_ivars_are_silent
    refute_fixture_offense("bare_ivar_test.rb")
  end

  def test_assigns_with_receiver_is_silent
    refute_fixture_offense("assigns_receiver_test.rb")
  end

  def test_assigns_with_dynamic_or_interpolated_argument_is_silent
    refute_fixture_offense("assigns_dynamic_test.rb")
  end

  def test_assigns_without_argument_is_silent
    refute_fixture_offense("assigns_no_arg_test.rb")
  end

  def test_csend_fires_through_bridge
    assert_fixture_offense("csend_instance_variable_get_test.rb", "instance_variable_get")
  end

  def test_allowed_receiver_is_silent
    refute_fixture_offense("allowed_receiver_test.rb")
  end

  def test_metadata_is_complete
    meta = RuboCop::Cop::Metz::TestAssertsOnInternals.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_equal :manual, meta[:fix_safety]
    assert_equal 3, meta[:suggested_next_moves].size
  end

  private

  def assert_fixture_offense(basename, method_name)
    metz_inspect(read_fixture(basename), basename)

    assert_equal [expected_message(method_name)], test_asserts_on_internals_offenses.map(&:message)
  end

  def refute_fixture_offense(basename)
    refute_offense(read_fixture(basename), file: basename)
  end

  def test_asserts_on_internals_offenses
    Array(@metz_offenses).select { |o| o.cop_name == "Metz/TestAssertsOnInternals" }
  end

  def expected_message(method_name)
    format(MESSAGE, method: method_name)
  end

  def read_fixture(basename)
    File.read(fixture_path(basename))
  end

  def fixture_path(basename)
    File.join(FIXTURE_DIR, basename)
  end

  def default_yml
    YAML.load_file(File.expand_path("../../../config/default.yml", __dir__))
  end
end
