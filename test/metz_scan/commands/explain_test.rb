# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "rubocop-metz"
require "metz_scan/commands/explain"

module MetzScan
  module Commands
    class ExplainTest < Minitest::Test
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

      def test_explain_demeter_prints_full_metadata_and_config_knobs
        code = Explain.run(["Metz/DemeterTrainWreck"], stdout: @stdout, stderr: @stderr)
        assert_equal 0, code
        assert_full_metadata_in_output("Metz/DemeterTrainWreck", @stdout.string)
        %w[Max AllowedReceivers].each { |key| assert_includes @stdout.string, key }
      end

      def assert_full_metadata_in_output(cop_name, output)
        klass = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
        assert_includes output, klass.why_it_matters
        assert_includes output, klass.fix_safety.to_s
        klass.suggested_next_moves.each { |move| assert_includes output, move }
      end

      def test_explain_succeeds_for_every_metz_cop_registered_through_m5
        ALL_METZ_COPS.each { |cop_name| assert_explain_succeeds(cop_name) }
      end

      def assert_explain_succeeds(cop_name)
        stdout = StringIO.new
        code = Explain.run([cop_name], stdout: stdout, stderr: StringIO.new)
        assert_equal 0, code, "explain #{cop_name} expected to exit 0"
        assert_match(/#{Regexp.escape(cop_name)}.*Why it matters:.*Fix safety:/m, stdout.string)
      end

      def test_explain_unknown_cop_exits_non_zero_with_friendly_message
        code = Explain.run(["Nonexistent/Cop"], stdout: @stdout, stderr: @stderr)
        refute_equal 0, code
        assert_unknown_cop_error(@stdout.string + @stderr.string)
      end

      def assert_unknown_cop_error(combined)
        assert_includes combined, "Nonexistent/Cop"
        assert_match(/no such cop|not found|unknown cop/i, combined)
        assert_match(/metz-scan rules/, combined)
        refute_match(/\.rb:\d+:in /, combined)
      end

      def test_explain_non_metz_cop_treated_as_unknown
        code = Explain.run(["Metrics/ClassLength"], stdout: @stdout, stderr: @stderr)
        refute_equal 0, code
        assert_includes @stderr.string, "Metrics/ClassLength"
      end

      def test_explain_without_argument_exits_non_zero_with_usage
        code = Explain.run([], stdout: @stdout, stderr: @stderr)
        refute_equal 0, code
        assert_match(/Usage: metz-scan explain/, @stderr.string)
      end
    end
  end
end
