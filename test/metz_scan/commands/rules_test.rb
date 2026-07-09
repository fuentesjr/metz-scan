# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"

require "rubocop-metz"
require "metz_scan/commands/rules"

module MetzScan
  module Commands
    class RulesTest < Minitest::Test
      ALL_METZ_COPS = %w[
        Metz/ClassesTooLong
        Metz/ControllersTooManyDirectCollaborators
        Metz/DemeterTrainWreck
        Metz/MethodsTooLong
        Metz/MethodsTooManyParameters
        Metz/TestAssertsOnInternals
        Metz/TestReachesPrivate
        Metz/ViewsDeepNavigation
      ].freeze

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
      end

      def test_text_output_lists_every_metz_cop_registered_through_m5
        code = Rules.run([], stdout: @stdout, stderr: @stderr)

        assert_equal 0, code
        ALL_METZ_COPS.each { |name| assert_includes @stdout.string, name }
      end

      def test_text_output_pairs_each_cop_with_its_why_it_matters_one_liner
        Rules.run([], stdout: @stdout, stderr: @stderr)
        ALL_METZ_COPS.each { |name| assert_why_on_row(name) }
      end

      def assert_why_on_row(cop_name)
        klass = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
        row = @stdout.string.lines.find { |line| line.include?(cop_name) }
        refute_nil row, "no row for #{cop_name}"
        assert_includes row, klass.why_it_matters
      end

      def test_text_output_is_uncolored_when_stdout_is_not_a_tty
        Rules.run([], stdout: @stdout, stderr: @stderr)

        refute_match(/\e\[/, @stdout.string)
      end

      def test_text_output_emits_ansi_color_when_stdout_is_a_tty
        tty_stdout = TTYStringIO.new
        Rules.run([], stdout: tty_stdout, stderr: @stderr)

        assert_match(/\e\[/, tty_stdout.string)
      end

      def test_json_flag_emits_entry_for_each_registered_metz_cop
        Rules.run(["--json"], stdout: @stdout, stderr: @stderr)

        parsed = JSON.parse(@stdout.string)

        assert_kind_of Array, parsed
        assert_equal ALL_METZ_COPS.sort, parsed.map { |entry| entry.fetch("name") }.sort
      end

      def test_json_entries_have_required_keys_and_types
        Rules.run(["--json"], stdout: @stdout, stderr: @stderr)
        JSON.parse(@stdout.string).each { |entry| assert_valid_json_entry(entry) }
      end

      def assert_valid_json_entry(entry)
        assert_kind_of String, entry["name"]
        refute_empty entry["why_it_matters"]
        assert_includes %w[safe unsafe manual], entry["fix_safety"]
        assert_kind_of Array, entry["suggested_next_moves"]
        refute_empty entry["suggested_next_moves"]
      end

      class TTYStringIO < StringIO
        def tty?
          true
        end
      end
    end
  end
end
