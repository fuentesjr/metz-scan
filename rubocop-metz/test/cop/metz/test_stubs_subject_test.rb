# frozen_string_literal: true

require_relative "../../test_helper"

class CopMetzTestStubsSubjectTest < Minitest::Test
  include Metz::Test::CopHelper

  FIXTURE_DIR = File.expand_path("../../fixtures/test_stubs_subject", __dir__)
  MESSAGE = "Test stubs the subject under test; stub the subject's collaborators, " \
            "not the object whose behavior the test verifies."
  CANONICAL_FIXTURES = %w[
    implicit_subject_expect_spec.rb
    implicit_subject_allow_spec.rb
    bare_describe_spec.rb
    is_expected_spec.rb
    named_subject_spec.rb
    subject_bang_spec.rb
    negated_not_to_spec.rb
    negated_to_not_spec.rb
    receive_messages_spec.rb
    receive_message_chain_spec.rb
    have_received_spec.rb
    nested_matcher_spec.rb
    inherited_named_subject_spec.rb
    let_override_then_inner_subject_spec.rb
    csend_subject_spec.rb
    collaborator_spec.rb
    sibling_subject_spec.rb
    let_override_spec.rb
    let_bang_override_spec.rb
    described_class_spec.rb
    arbitrary_local_instance_spec.rb
    non_stub_matcher_spec.rb
    is_expected_non_stub_spec.rb
    message_result_spec.rb
  ].freeze

  def cop_class
    RuboCop::Cop::Metz::TestStubsSubject
  end

  def test_canonical_fixtures_are_vendored
    CANONICAL_FIXTURES.each { |basename| assert File.file?(fixture_path(basename)) }
  end

  def test_cop_is_registered_in_global_registry
    klass = RuboCop::Cop::Registry.global.find_by_cop_name("Metz/TestStubsSubject")

    assert_equal RuboCop::Cop::Metz::TestStubsSubject, klass
  end

  def test_default_yaml_ships_opt_in_with_rspec_only_include
    entry = default_yml.fetch("Metz/TestStubsSubject")

    assert_equal false, entry["Enabled"]
    assert_equal "refactor", entry["Severity"]
    assert_equal ["**/*_spec.rb"], Array(entry["Include"])
  end

  def test_implicit_subject_expect_fires
    assert_fixture_offense("implicit_subject_expect_spec.rb")
  end

  def test_implicit_subject_allow_fires
    assert_fixture_offense("implicit_subject_allow_spec.rb")
  end

  def test_bare_describe_fires
    assert_fixture_offense("bare_describe_spec.rb")
  end

  def test_is_expected_fires
    assert_fixture_offense("is_expected_spec.rb")
  end

  def test_named_subject_fires
    assert_fixture_offense("named_subject_spec.rb")
  end

  def test_bang_subject_fires
    assert_fixture_offense("subject_bang_spec.rb")
  end

  def test_not_to_fires
    assert_fixture_offense("negated_not_to_spec.rb")
  end

  def test_to_not_fires
    assert_fixture_offense("negated_to_not_spec.rb")
  end

  def test_receive_messages_fires
    assert_fixture_offense("receive_messages_spec.rb")
  end

  def test_receive_message_chain_fires
    assert_fixture_offense("receive_message_chain_spec.rb")
  end

  def test_have_received_fires
    assert_fixture_offense("have_received_spec.rb")
  end

  def test_nested_matcher_fires
    assert_fixture_offense("nested_matcher_spec.rb")
  end

  def test_subject_name_inherited_into_nested_context_fires
    assert_fixture_offense("inherited_named_subject_spec.rb")
  end

  def test_inner_subject_readds_outer_let_override
    assert_fixture_offense("let_override_then_inner_subject_spec.rb")
  end

  def test_csend_fires_through_bridge
    assert_fixture_offense("csend_subject_spec.rb")
  end

  def test_collaborator_is_silent
    refute_fixture_offense("collaborator_spec.rb")
  end

  def test_sibling_subject_name_is_silent
    refute_fixture_offense("sibling_subject_spec.rb")
  end

  def test_let_override_is_silent
    refute_fixture_offense("let_override_spec.rb")
  end

  def test_let_bang_override_is_silent
    refute_fixture_offense("let_bang_override_spec.rb")
  end

  def test_described_class_is_silent
    refute_fixture_offense("described_class_spec.rb")
  end

  def test_arbitrary_local_instance_is_silent
    refute_fixture_offense("arbitrary_local_instance_spec.rb")
  end

  def test_non_stub_matcher_is_silent
    refute_fixture_offense("non_stub_matcher_spec.rb")
  end

  def test_is_expected_non_stub_matcher_is_silent
    refute_fixture_offense("is_expected_non_stub_spec.rb")
  end

  def test_message_result_receiver_is_silent
    refute_fixture_offense("message_result_spec.rb")
  end

  def test_metadata_is_complete
    meta = RuboCop::Cop::Metz::TestStubsSubject.metz_metadata

    refute_empty meta[:why_it_matters]
    assert_equal :manual, meta[:fix_safety]
    assert_equal 3, meta[:suggested_next_moves].size
  end

  private

  def assert_fixture_offense(basename)
    metz_inspect(read_fixture(basename), basename)

    assert_equal [MESSAGE], test_stubs_subject_offenses.map(&:message)
  end

  def refute_fixture_offense(basename)
    refute_offense(read_fixture(basename), file: basename)
  end

  def test_stubs_subject_offenses
    Array(@metz_offenses).select { |o| o.cop_name == "Metz/TestStubsSubject" }
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
