# frozen_string_literal: true

# Minitest file containing DELIBERATELY-INVERTED assertions of the
# `Metz::Test::CopHelper` macros. Every test in this file MUST fail when
# Minitest runs it; that is the proof that the helper is not silently
# green. This file is NOT named `*_test.rb` and lives under
# `rubocop-metz/test/audit/` precisely so the project's normal test
# runner does not pick it up. It is exercised exclusively by the
# `cop_helper_inverted_audit.rb` driver, which runs this file in a
# subprocess and then inverts the exit code.

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
$LOAD_PATH.unshift(File.expand_path("..", __dir__))

require "minitest/autorun"
require "rubocop-metz"
require "metz/test/cop_helper"
require "metz/test/fixtures/helper_fixture_cop"

class InvertedAssertionAudit < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    HelperFixtureCop
  end

  def test_refute_offense_against_offending_source_must_fail
    refute_offense('puts "this fires the cop"')
  end

  def test_assert_offense_with_wrong_message_must_fail
    assert_offense(<<~RUBY)
      puts "wrong-message"
      ^^^^^^^^^^^^^^^^^^^^ A message that the fixture cop never emits.
    RUBY
  end

  def test_assert_offense_for_clean_source_must_fail
    assert_offense(<<~RUBY)
      x = 1
      ^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
    RUBY
  end
end
