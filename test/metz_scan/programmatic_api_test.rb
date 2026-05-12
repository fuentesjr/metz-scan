# frozen_string_literal: true

require "minitest/autorun"
require "stringio"

require "metz_scan"

module MetzScan
  class ProgrammaticApiTest < Minitest::Test
    def setup
      @stdout = StringIO.new
      @stderr = StringIO.new
    end

    def test_metz_scan_cli_constant_is_defined_after_require
      assert defined?(MetzScan::CLI), "expected MetzScan::CLI to be defined after `require 'metz_scan'`"
    end

    def test_new_run_returns_integer_exit_code_for_rules_subcommand
      code = MetzScan::CLI.new(stdout: @stdout, stderr: @stderr).run(["rules"])

      assert_kind_of Integer, code
      assert_equal 0, code
    end

    def test_run_writes_same_output_the_shell_command_would_produce
      MetzScan::CLI.new(stdout: @stdout, stderr: @stderr).run(["rules"])

      assert_includes @stdout.string, "Metz/ClassesTooLong"
      assert_includes @stdout.string, "Metz/DemeterTrainWreck"
      assert_empty @stderr.string
    end

    def test_new_with_no_arguments_uses_real_stdout_and_stderr_defaults
      cli = MetzScan::CLI.new

      assert_kind_of MetzScan::CLI, cli
    end
  end
end
