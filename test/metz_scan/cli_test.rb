# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan/cli"

module MetzScan
  class CLITest < Minitest::Test
    def setup
      @stdout = StringIO.new
      @stderr = StringIO.new
    end

    def test_version_flag_prints_metz_scan_version_and_exits_zero
      code = MetzScan::CLI.start(["--version"], stdout: @stdout, stderr: @stderr)

      assert_equal 0, code
      assert_equal MetzScan::VERSION, @stdout.string.strip
      assert_empty @stderr.string
    end

    def test_short_version_flag_matches_long_form
      code = MetzScan::CLI.start(["-v"], stdout: @stdout, stderr: @stderr)

      assert_equal 0, code
      assert_equal MetzScan::VERSION, @stdout.string.strip
    end

    def test_help_flag_lists_all_four_subcommands_on_stdout_and_exits_zero
      code = MetzScan::CLI.start(["--help"], stdout: @stdout, stderr: @stderr)

      assert_equal 0, code
      assert_subcommands_in @stdout.string
      assert_empty @stderr.string
    end

    def test_bare_invocation_prints_help_to_stderr_and_exits_non_zero
      code = MetzScan::CLI.start([], stdout: @stdout, stderr: @stderr)

      refute_equal 0, code
      assert_subcommands_in @stderr.string
    end

    def test_unknown_subcommand_exits_non_zero_with_help
      code = MetzScan::CLI.start(["bogus"], stdout: @stdout, stderr: @stderr)

      refute_equal 0, code
      assert_match(/unknown subcommand 'bogus'/, @stderr.string)
      assert_subcommands_in @stderr.string
    end

    def test_explain_subcommand_dispatches_to_handler_and_exits_zero
      code = MetzScan::CLI.start(["explain", "Metz/DemeterTrainWreck"], stdout: @stdout, stderr: @stderr)

      assert_equal 0, code
      assert_includes @stdout.string, "Metz/DemeterTrainWreck"
      assert_empty @stderr.string
    end

    def test_rules_subcommand_dispatches_to_handler_and_exits_zero
      code = MetzScan::CLI.start(["rules"], stdout: @stdout, stderr: @stderr)

      assert_equal 0, code
      assert_includes @stdout.string, "Metz/ClassesTooLong"
      assert_empty @stderr.string
    end

    private

    def assert_subcommands_in(output)
      %w[rules explain scan report].each do |name|
        assert_includes output, name, "expected help to mention '#{name}'"
      end
    end
  end
end
