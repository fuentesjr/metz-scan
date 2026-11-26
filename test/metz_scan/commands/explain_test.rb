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
        Metz/GodServiceClass
        Metz/MethodsTooLong
        Metz/MethodsTooManyParameters
        Metz/OperationsTooManyPublicMethods
        Metz/TestAssertsOnInternals
        Metz/TestReachesPrivate
        Metz/TestStubsSubject
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

      def test_explain_unknown_cop_exits_with_usage_error_with_friendly_message
        code = Explain.run(["Nonexistent/Cop"], stdout: @stdout, stderr: @stderr)
        assert_equal 64, code
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
        assert_equal 64, code
        assert_includes @stderr.string, "Metrics/ClassLength"
      end

      def test_explain_invalid_option_exits_with_usage_error_without_stack_trace
        code = Explain.run(["--bogus"], stdout: @stdout, stderr: @stderr)

        assert_equal 64, code
        assert_match(/metz-scan explain: invalid option: --bogus/, @stderr.string)
        refute_match(/\.rb:\d+:in /, @stdout.string + @stderr.string)
      end

      def test_explain_without_argument_exits_with_usage_error_with_usage
        code = Explain.run([], stdout: @stdout, stderr: @stderr)
        assert_equal 64, code
        assert_match(/Usage: metz-scan explain/, @stderr.string)
      end
    end

    class ExplainProjectAnalyzerTest < Minitest::Test
      %w[
        ServiceSoup RepeatedBranching DeepInheritanceTree PackageDependencyPressure NamespaceLeakPressure
        ImplicitContextPressure RepeatedQueryCriteria SubclassOverridePressure TestCallsPrivateMethod
      ].each do |analyzer|
        define_method("test_explain_supports_project_analyzer_#{analyzer}") do
          explain_project_analyzer("MetzProject/#{analyzer}")
        end
      end

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
      end

      def test_explain_service_soup_describes_the_validated_default_analyzer
        output = project_analyzer_metadata("MetzProject/ServiceSoup")
        assert_match(/workflow.*orchestration|orchestration.*workflow/i, rationale(output))
        assert_analyzer_status(output, "validated", "yes", "design pressure")
      end

      def test_explain_package_dependency_pressure_describes_the_opt_in_candidate
        output = project_analyzer_metadata("MetzProject/PackageDependencyPressure")
        assert_match(/package.*(?:dependenc|boundar)|(?:dependenc|boundar).*package/i, rationale(output))
        assert_analyzer_status(output, "candidate", "no", "manual review")
      end

      def test_explain_unknown_project_analyzer_exits_with_discovery_guidance
        code = Explain.run(["MetzProject/Nonexistent"], stdout: @stdout, stderr: @stderr)

        assert_equal 64, code
        assert_includes @stderr.string, "MetzProject/Nonexistent"
        assert_match(/metz-scan (?:project-analyzers|rules)\b/, @stderr.string)
        refute_match(/Traceback|\.rb:\d+:in /, @stdout.string + @stderr.string)
      end

      private

      def explain_project_analyzer(rule_id)
        code = Explain.run([rule_id], stdout: @stdout, stderr: @stderr)
        assert_equal 0, code, @stderr.string

        assert_includes @stdout.string.lines.map(&:chomp), rule_id
        refute_empty rationale(@stdout.string)
        @stdout.string
      end

      def project_analyzer_metadata(rule_id)
        output = explain_project_analyzer(rule_id)
        assert_includes output.lines.map(&:chomp).each_cons(2).to_a, [rule_id, "=" * rule_id.length]
        assert_match(/^Fix safety: manual$/, output)
        assert_match(/^Suggested next moves:[ \t]*\n[ \t]*- \S/, output)
        output
      end

      def rationale(output)
        output[/^Why it matters:[ \t]*\n?(.*?)(?=^[A-Z][^:\n]*:|\z)/m, 1].to_s.split.join(" ")
      end

      def assert_analyzer_status(output, status, default_scan, triage)
        assert_match(/^Status:\s*#{status}\b/, output)
        assert_match(/Default scan: #{default_scan}\b/, output)
        assert_match(/Confidence: medium\b/, output)
        assert_match(/Triage: #{triage}\b/, output)
      end
    end
  end
end
