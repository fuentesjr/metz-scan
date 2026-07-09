# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzTestReachesPrivateTest < Minitest::Test
  include Metz::Test::CopHelper

  FIXTURE_DIR = File.expand_path("../../fixtures/test_reaches_private", __dir__)
  EXPECTED_SEND_MESSAGE = "Test reaches past the public interface with " \
                          "`send(:private_thing)`; `send` bypasses method visibility — " \
                          "exercise the object through its public API."
  CANONICAL_FIXTURES = %w[
    minitest_private_reach_test.rb
    rspec_private_reach_spec.rb
    public_send_test.rb
    allowed_method_test.rb
    operator_send_test.rb
    dynamic_send_test.rb
    csend_private_reach_test.rb
    underscore_send_test.rb
    string_private_reach_test.rb
    allowed_receiver_test.rb
  ].freeze

  def cop_class
    RuboCop::Cop::Metz::TestReachesPrivate
  end

  def cop_config
    {
      "AllowedMethods" => %w[define_method remove_const include extend prepend alias_method],
      "AllowedReceivers" => %w[reflection_target]
    }
  end

  def test_canonical_fixtures_are_vendored
    CANONICAL_FIXTURES.each { |basename| assert File.file?(fixture_path(basename)) }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name("Metz/TestReachesPrivate")

    assert_equal RuboCop::Cop::Metz::TestReachesPrivate, klass
  end

  def test_default_yaml_ships_opt_in_with_test_includes
    entry = default_yml.fetch("Metz/TestReachesPrivate")

    assert_equal false, entry["Enabled"]
    assert_equal "refactor", entry["Severity"]
    assert_equal [], entry["AllowedReceivers"]
    assert_includes Array(entry["Include"]), "**/*_test.rb"
    assert_includes Array(entry["AllowedMethods"]), "define_method"
  end

  def test_minitest_literal_send_fires_one_offense
    assert_fixture_offense("minitest_private_reach_test.rb", EXPECTED_SEND_MESSAGE)
  end

  def test_rspec_literal_send_fires_one_offense
    assert_fixture_offense("rspec_private_reach_spec.rb", EXPECTED_SEND_MESSAGE)
  end

  def test_public_send_is_silent
    refute_fixture_offense("public_send_test.rb")
  end

  def test_allowed_method_is_silent
    refute_fixture_offense("allowed_method_test.rb")
  end

  def test_operator_sends_are_silent
    refute_fixture_offense("operator_send_test.rb")
  end

  def test_dynamic_method_names_are_silent
    refute_fixture_offense("dynamic_send_test.rb")
  end

  def test_csend_fires_through_bridge
    message = EXPECTED_SEND_MESSAGE.sub(":private_thing", ":bar")

    assert_fixture_offense("csend_private_reach_test.rb", message)
  end

  def test_underscore_send_fires
    message = EXPECTED_SEND_MESSAGE.sub("`send(", "`__send__(")

    assert_fixture_offense("underscore_send_test.rb", message)
  end

  def test_string_literal_name_fires
    assert_fixture_offense("string_private_reach_test.rb", EXPECTED_SEND_MESSAGE)
  end

  def test_allowed_receiver_is_silent
    refute_fixture_offense("allowed_receiver_test.rb")
  end

  def test_metadata_mentions_interface_and_implementation
    why = RuboCop::Cop::Metz::TestReachesPrivate.metz_metadata[:why_it_matters]

    assert_match(/interface/i, why)
    assert_match(/implementation/i, why)
  end

  private

  def assert_fixture_offense(basename, message)
    metz_inspect(read_fixture(basename), basename)

    assert_equal [message], test_reaches_private_offenses.map(&:message)
  end

  def refute_fixture_offense(basename)
    refute_offense(read_fixture(basename), file: basename)
  end

  def test_reaches_private_offenses
    Array(@metz_offenses).select { |o| o.cop_name == "Metz/TestReachesPrivate" }
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
