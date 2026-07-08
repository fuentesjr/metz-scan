# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanErrorTest < Minitest::Test
      def test_invalid_rubocop_config_exits_non_zero_with_friendly_message
        Dir.mktmpdir("metz-scan-error-test") do |dir|
          assert_invalid_config_error(*invalid_config_scan(dir, "--all-cops"))
        end
      end

      def test_default_scan_ignores_invalid_project_config
        Dir.mktmpdir("metz-scan-error-test") do |dir|
          code, output = invalid_config_scan(dir)

          assert_equal 0, code
          assert_no_stack_trace(output)
        end
      end

      private

      def invalid_config_scan(dir, *flags)
        stdout = StringIO.new
        stderr = StringIO.new
        code = run_invalid_config_scan(dir, stdout, stderr, flags)
        [code, stdout.string + stderr.string]
      end

      def run_invalid_config_scan(dir, stdout, stderr, flags)
        write_invalid_config_fixture(dir)
        Scan.run([dir, *flags], stdout: stdout, stderr: stderr)
      end

      def write_invalid_config_fixture(dir)
        File.write(File.join(dir, ".rubocop.yml"), "AllCops: [\n")
        write_valid_fixture(dir)
      end

      def write_valid_fixture(dir)
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

    class ScanLoadErrorTest < Minitest::Test
      EXTERNAL_PLUGIN_CONFIG = <<~YAML
        plugins:
          - rubocop-performance
      YAML
      MISSING_RUBOCOP_METZ_SHIM = <<~RUBY
        module Kernel
          alias __metz_scan_original_require require

          def require(feature)
            raise LoadError, "cannot load such file -- rubocop-metz" if feature == "rubocop-metz"

            __metz_scan_original_require(feature)
          end
        end
      RUBY
      EXTENSIONLESS_STACK_TRACE = <<~TEXT
        Traceback (most recent call last):
        bin/metz-scan:10:in `<main>'
        cannot load such file -- rubocop-performance
      TEXT

      def test_all_cops_missing_target_plugin_reports_config_error_without_backtrace
        with_external_plugin_config { |dir| assert_missing_target_plugin(metz_scan_subprocess(dir, "--all-cops")) }
      end

      def test_missing_rubocop_metz_plugin_still_names_rubocop_metz
        with_missing_rubocop_metz { |dir| assert_missing_rubocop_metz(metz_scan_subprocess(dir, env: shim_env(dir))) }
      end

      def test_concise_message_filters_extensionless_entrypoint_stack_frames
        assert_equal "cannot load such file -- rubocop-performance", Scan::Runner.concise_message(EXTENSIONLESS_STACK_TRACE)
      end

      private

      def with_external_plugin_config
        with_temp_scan_dir do |dir|
          write_external_plugin_config_fixture(dir)
          yield dir
        end
      end

      def with_missing_rubocop_metz
        with_temp_scan_dir do |dir|
          write_valid_fixture(dir)
          write_missing_rubocop_metz_shim(dir)
          yield dir
        end
      end

      def with_temp_scan_dir(&)
        Dir.mktmpdir("metz-scan-error-test", &)
      end

      def assert_missing_target_plugin(result)
        output, status = output_and_status(result)
        assert_equal 2, status.exitstatus
        assert_match(/cannot load such file -- rubocop-performance/, output)
        refute_match(/could not load rubocop-metz/, output)
        assert_no_stack_trace(output)
      end

      def assert_missing_rubocop_metz(result)
        output, status = output_and_status(result)
        assert_equal 2, status.exitstatus
        assert_match(/could not load rubocop-metz: cannot load such file -- rubocop-metz/, output)
        assert_no_stack_trace(output)
      end

      def metz_scan_subprocess(dir, *flags, env: {})
        Open3.capture3(
          subprocess_env(env),
          "bundle", "exec", RbConfig.ruby, bin_path, "scan", dir, *flags,
          chdir: repo_root
        )
      end

      def output_and_status(result)
        stdout, stderr, status = result
        [stdout + stderr, status]
      end

      def write_external_plugin_config_fixture(dir)
        File.write(File.join(dir, ".rubocop.yml"), EXTERNAL_PLUGIN_CONFIG)
        write_valid_fixture(dir)
      end

      def write_valid_fixture(dir)
        File.write(File.join(dir, "sample.rb"), "# frozen_string_literal: true\n")
      end

      def write_missing_rubocop_metz_shim(dir)
        File.write(File.join(dir, "missing_rubocop_metz.rb"), MISSING_RUBOCOP_METZ_SHIM)
      end

      def subprocess_env(env)
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile") }.merge(env)
      end

      def shim_env(dir)
        shim = File.join(dir, "missing_rubocop_metz.rb")
        rubyopt = [ENV.fetch("RUBYOPT", nil), "-r#{shim}"].compact.join(" ")
        { "RUBYOPT" => rubyopt }
      end

      def bin_path
        File.join(repo_root, "bin/metz-scan")
      end

      def repo_root
        File.expand_path("../../..", __dir__)
      end

      def assert_no_stack_trace(output)
        refute_match(/Traceback/, output)
        refute_match(/\.rb:\d+:in [`']/, output)
        refute_match(%r{bin/metz-scan:\d+:in [`']}, output)
      end
    end
  end
end
