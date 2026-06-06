# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanTest < Minitest::Test
      VIOLATING_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        class Sample
          def long_method
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            f = 6
            g = 7
            h = 8
            [a, b, c, d, e, f, g, h]
          end
        end
      RUBY

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-scan-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_text_format_default_groups_by_metz_cop_with_location_lines
        code = scan_violating([@tmpdir])
        assert_text_grouped_output(code)
      end

      def test_text_format_default_is_not_json
        scan_violating([@tmpdir])
        assert_raises(JSON::ParserError) { JSON.parse(@stdout.string) }
      end

      def test_json_format_passes_through_metz_json_formatter_shape
        scan_violating([@tmpdir, "--format", "json"])
        assert_metz_offense_shape
      end

      def test_sarif_format_emits_2_1_0_structure_with_driver_name
        scan_violating([@tmpdir, "--format", "sarif"])
        assert_sarif_2_1_0_shape
      end

      private

      def write_violating_fixture
        File.write(File.join(@tmpdir, "sample.rb"), VIOLATING_FIXTURE)
      end

      def scan_violating(argv)
        write_violating_fixture
        run_scan(argv)
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        if @original_rubocop_cache_root
          ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
        else
          ENV.delete("RUBOCOP_CACHE_ROOT")
        end
      end

      def metz_offense
        @metz_offense ||= json_offenses.find { |o| o["cop_name"].to_s.start_with?("Metz/") }
      end

      def json_offenses
        JSON.parse(@stdout.string).fetch("files").flat_map { |f| f.fetch("offenses") }
      end

      def assert_text_grouped_output(code)
        refute_equal 0, code, "expected non-zero exit when offenses found"
        assert_match(%r{^Metz/}m, @stdout.string, "expected a Metz/* cop heading")
        assert_match(/\.rb:\d+:\d+/, @stdout.string, "expected at least one location line")
        assert_no_stack_trace
      end

      def assert_metz_offense_shape
        refute_nil metz_offense, "expected at least one Metz/* offense"
        %w[why_it_matters fix_safety].each { |k| assert metz_offense.key?(k), "missing #{k}" }
        assert_kind_of Array, metz_offense["suggested_next_moves"]
        assert metz_offense.dig("location", "start_line"), "missing location.start_line"
      end

      def assert_sarif_2_1_0_shape
        doc = JSON.parse(@stdout.string)
        assert_equal "2.1.0", doc["version"]
        assert_kind_of Array, doc["runs"]
        assert_equal "metz-scan", doc.dig("runs", 0, "tool", "driver", "name")
      end

      def assert_no_stack_trace
        combined = @stdout.string + @stderr.string
        refute_match(/Traceback/, combined, "output should not contain a Ruby traceback")
        refute_match(/\.rb:\d+:in [`']/, combined, "output should not contain a stack frame")
      end
    end
  end
end
