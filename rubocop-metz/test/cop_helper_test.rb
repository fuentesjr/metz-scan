# frozen_string_literal: true

require_relative "test_helper"

class CopHelperTest < Minitest::Test
  include Metz::Test::CopHelper

  def cop_class
    HelperFixtureCop
  end

  def test_assert_offense_passes_when_caret_annotation_matches
    assert_offense(<<~RUBY)
      puts "hello"
      ^^^^^^^^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
    RUBY
  end

  def test_assert_offense_supports_replacement_keywords
    assert_offense(<<~RUBY, name: "puts")
      %{name} "hi"
      ^{name}^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
    RUBY
  end

  def test_assert_offense_accepts_abbreviated_message
    assert_offense(<<~RUBY)
      puts "hi"
      ^^^^^^^^^ HelperFixtureCop: Avoid bare `puts` [...]
    RUBY
  end

  def test_refute_offense_passes_when_no_offense_is_emitted
    refute_offense("p :silent")
  end

  def test_refute_offense_passes_for_empty_source
    refute_offense("")
  end

  def test_assert_offense_handles_multiple_offenses_on_separate_lines
    assert_offense(<<~RUBY)
      puts "one"
      ^^^^^^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
      x = 1
      puts "two"
      ^^^^^^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
    RUBY
  end

  def test_assert_correction_replaces_puts_with_logger_info
    assert_offense(<<~RUBY)
      puts "hi"
      ^^^^^^^^^ HelperFixtureCop: Avoid bare `puts` calls in production code.
    RUBY

    assert_correction(<<~RUBY)
      Rails.logger.info("hi")
    RUBY
  end
end
