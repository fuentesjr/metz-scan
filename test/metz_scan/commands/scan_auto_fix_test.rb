# frozen_string_literal: true

require "digest"
require "fileutils"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    module ScanAutoFixFixtures
      PARTIAL_FIXTURE = <<~RUBY
        # frozen_string_literal: true

        class Sample
          def long_method
            x =  1
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            f = 6
            [x, a, b, c, d, e, f]
          end
        end
      RUBY

      def assert_partial_dry_run_result(code, path, before)
        refute_equal 0, code
        assert_equal before, File.binread(path)
        assert_match(/^-    x =  1$/, @stdout.string)
        assert_match(/^\+    x = 1$/, @stdout.string)
        assert_match(%r{Metz/MethodsTooLong|Style/Documentation}, @stderr.string)
      end
    end

    class ScanAutoFixTest < Minitest::Test
      include ScanAutoFixFixtures

      SAFE_FIXTURE = <<~RUBY
        # frozen_string_literal: true

        def f
          x = 1
          y =  2
          return x + y
        end
      RUBY

      UNSAFE_ONLY_FIXTURE = "1 + 1\n"

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-autofix-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_auto_fix_changes_sha_of_safe_correctable_file
        path = write_fixture("bad.rb", SAFE_FIXTURE)
        before, code, after = run_with_shas(path, ["scan", @tmpdir, "--auto-fix"])
        refute_equal before, after, "expected file to change after --auto-fix"
        assert_includes [0, 1], code
      end

      def test_auto_fix_exits_zero_when_no_offenses_remain
        write_fixture("clean.rb", "# frozen_string_literal: true\n")
        assert_equal 0, run_cli(["scan", @tmpdir, "--auto-fix"])
      end

      def test_auto_fix_unsafe_corrects_offense_that_safe_run_skips
        path = write_fixture("needs_unsafe.rb", UNSAFE_ONLY_FIXTURE)
        before, after_safe, after_unsafe = run_safe_then_unsafe(path)
        assert_equal before, after_safe, "safe run unexpectedly modified file"
        refute_equal after_safe, after_unsafe, "--unsafe should have modified file"
        assert_includes File.read(path), "frozen_string_literal"
      end

      def test_dry_run_leaves_files_byte_identical_and_prints_diff
        path = write_fixture("bad.rb", SAFE_FIXTURE)
        before, code, after = run_with_shas(path, ["scan", @tmpdir, "--auto-fix", "--dry-run"])
        assert_equal 0, code
        assert_equal before, after, "dry-run must not modify files"
        assert_match(/^[+-]/, @stdout.string)
      end

      def test_auto_fix_on_clean_empty_directory_exits_zero
        assert_equal 0, run_cli(["scan", @tmpdir, "--auto-fix"])
        assert_empty @stderr.string
      end

      def test_dry_run_on_clean_empty_directory_exits_zero
        assert_equal 0, run_cli(["scan", @tmpdir, "--auto-fix", "--dry-run"])
        assert_empty @stderr.string
      end

      def test_dry_run_restores_files_when_offenses_are_corrected
        path = write_fixture("bad.rb", SAFE_FIXTURE)
        before = File.binread(path)
        run_cli(["scan", @tmpdir, "--auto-fix", "--dry-run"])
        assert_equal before, File.binread(path)
      end

      def test_dry_run_prints_diff_when_corrected_file_still_has_offenses
        path = write_fixture("partial.rb", PARTIAL_FIXTURE)
        before = File.binread(path)
        code = run_cli(["scan", @tmpdir, "--auto-fix", "--dry-run"])

        assert_partial_dry_run_result(code, path, before)
      end

      def test_dry_run_returns_rubocop_status_when_rubocop_fails
        path = write_fixture("syntax_error.rb", "def broken(\n")
        assert_failed_dry_run_preserves(path)
      end

      def assert_failed_dry_run_preserves(path)
        before = File.binread(path)
        code = run_cli(["scan", @tmpdir, "--auto-fix", "--dry-run"])
        refute_equal 0, code
        assert_equal before, File.binread(path)
        assert_match(%r{Lint/Syntax|unexpected|unterminated}i, @stderr.string)
      end

      private

      def write_fixture(name, content)
        path = File.join(@tmpdir, name)
        File.write(path, content)
        path
      end

      def sha256(path)
        Digest::SHA256.hexdigest(File.binread(path))
      end

      def run_cli(argv)
        require "metz_scan/cli"
        MetzScan::CLI.start(argv, stdout: @stdout, stderr: @stderr)
      end

      def run_with_shas(path, argv)
        before = sha256(path)
        code = run_cli(argv)
        [before, code, sha256(path)]
      end

      def run_safe_then_unsafe(path)
        before = sha256(path)
        run_cli(["scan", @tmpdir, "--auto-fix"])
        after_safe = sha256(path)
        run_cli(["scan", @tmpdir, "--auto-fix", "--unsafe"])
        [before, after_safe, sha256(path)]
      end
    end
  end
end
