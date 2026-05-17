# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanErrorTest < Minitest::Test
      def test_invalid_rubocop_config_exits_non_zero_with_friendly_message
        Dir.mktmpdir("metz-scan-error-test") do |dir|
          assert_invalid_config_error(*invalid_config_scan(dir))
        end
      end

      private

      def invalid_config_scan(dir)
        stdout = StringIO.new
        stderr = StringIO.new
        code = run_invalid_config_scan(dir, stdout, stderr)
        [code, stdout.string + stderr.string]
      end

      def run_invalid_config_scan(dir, stdout, stderr)
        write_invalid_config_fixture(dir)
        Scan.run([dir], stdout: stdout, stderr: stderr)
      end

      def write_invalid_config_fixture(dir)
        File.write(File.join(dir, ".rubocop.yml"), "AllCops: [\n")
        File.write(File.join(dir, "sample.rb"), "# frozen_string_literal: true\n")
      end

      def assert_invalid_config_error(code, output)
        assert_equal 2, code
        assert_match(/RuboCop failed/i, output)
        assert_no_stack_trace(output)
      end

      def assert_no_stack_trace(output)
        refute_match(/Traceback/, output)
        refute_match(/\.rb:\d+:in [`']/, output)
      end
    end
  end
end
