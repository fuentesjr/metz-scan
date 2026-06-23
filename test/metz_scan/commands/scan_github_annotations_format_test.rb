# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class ScanGithubAnnotationsFormatTest < Minitest::Test
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
        @tmpdir = Dir.mktmpdir("metz-scan-gh-annotations-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_github_annotations_format_emits_workflow_commands
        code = scan_violating([@tmpdir, "--format", "gh-annotations"])

        refute_equal 0, code
        assert_match(%r{^::warning file=.*sample\.rb,line=\d+,col=\d+,title=Metz/}, @stdout.string)
      end

      private

      def write_violating_fixture
        File.write(File.join(@tmpdir, "sample.rb"), VIOLATING_FIXTURE)
      end

      def scan_violating(argv)
        write_violating_fixture
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
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end
  end
end
