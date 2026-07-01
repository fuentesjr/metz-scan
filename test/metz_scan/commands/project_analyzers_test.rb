# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"

require "metz_scan/commands/project_analyzers"

module MetzScan
  module Commands
    class ProjectAnalyzersTest < Minitest::Test
      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
      end

      def test_text_output_lists_status_and_default_output_eligibility
        code = ProjectAnalyzers.run([], stdout: @stdout, stderr: @stderr)

        assert_equal 0, code
        assert_text_output_lists_status_and_default_output_eligibility
      end

      def assert_text_output_lists_status_and_default_output_eligibility
        assert_includes @stdout.string, "MetzProject/ServiceSoup"
        assert_includes @stdout.string, "validated"
        assert_includes service_soup_row, "yes"
        assert_includes deep_inheritance_row, "no"
      end

      def test_json_output_lists_machine_readable_project_analyzer_metadata
        ProjectAnalyzers.run(["--json"], stdout: @stdout, stderr: @stderr)

        parsed = JSON.parse(@stdout.string)
        assert_json_default_output_flags(parsed)
        assert_json_statuses(parsed)
      end

      def assert_json_default_output_flags(parsed)
        assert_default_output(parsed, "MetzProject/ServiceSoup", true)
        assert_default_output(parsed, "MetzProject/DeepInheritanceTree", false)
        assert_default_output(parsed, "MetzProject/ImplicitContextPressure", false)
      end

      def assert_json_statuses(parsed)
        assert_status(parsed, "MetzProject/DeepInheritanceTree", "validated")
        assert_status(parsed, "MetzProject/ImplicitContextPressure", "candidate")
      end

      def test_unknown_option_exits_nonzero_with_usage
        code = ProjectAnalyzers.run(["--bogus"], stdout: @stdout, stderr: @stderr)

        refute_equal 0, code
        assert_match(/Usage: metz-scan project-analyzers/, @stderr.string)
      end

      private

      def service_soup_row
        row_for("MetzProject/ServiceSoup")
      end

      def deep_inheritance_row
        row_for("MetzProject/DeepInheritanceTree")
      end

      def row_for(name)
        @stdout.string.lines.find { |line| line.include?(name) }
      end

      def assert_default_output(entries, name, expected)
        assert_equal expected, entry_for(entries, name).fetch("default_output")
      end

      def assert_status(entries, name, expected)
        assert_equal expected, entry_for(entries, name).fetch("status")
      end

      def entry_for(entries, name)
        entries.find { |entry| entry.fetch("name") == name }
      end
    end
  end
end
