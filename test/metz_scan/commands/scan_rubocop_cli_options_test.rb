# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

module MetzScan
  module Commands
    module ScanRubocopCliOptionsHelpers
      LONG_METHOD_RUBY = <<~RUBY
        # frozen_string_literal: true

        class LongMethodSample
          def call
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            a + b + c + d + e
          end
        end
      RUBY

      FIXABLE_STOCK_RUBY = "puts 'hi'\n"
      NOTE_PREFIX = "metz-scan: note: ignoring RuboCop CLI options from "
      NOTE_SUFFIX = "; configure settings in .rubocop.yml instead\n"
      SCAN_MODES = [
        %w[. --format json],
        %w[. --all-cops --format json]
      ].freeze

      def run_scan(chdir, *args, rubocop_opts: nil)
        Dir.mktmpdir("metz-scan-cli-opts-cache") do |cache|
          env = scan_env(File.realpath(cache), rubocop_opts)
          ScanSubprocessSupport::Result.new(*Open3.capture3(env, *scan_cmd(args), chdir: chdir))
        end
      end

      def scan_env(cache, rubocop_opts)
        {
          "BUNDLE_GEMFILE" => File.join(ScanSubprocessSupport::REPO_ROOT, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => cache,
          "RUBOCOP_OPTS" => rubocop_opts
        }
      end

      def scan_cmd(args)
        ["bundle", "exec", RbConfig.ruby, File.join(ScanSubprocessSupport::REPO_ROOT, "bin/metz-scan"), "scan", *args]
      end

      def assert_long_method_offense(result)
        assert_equal 1, result.exitstatus, failure_context(result)
        assert_equal 1, result.json.dig("summary", "offense_count"), failure_context(result)
        assert_equal ["Metz/MethodsTooLong"], result.json.dig("summary", "offenses_by_cop").keys
      end

      def assert_all_cops_unchanged_json(dir, result)
        assert_equal 1, result.exitstatus, failure_context(result)
        assert_equal FIXABLE_STOCK_RUBY, File.binread(File.join(dir, "fixable.rb"))
        assert_operator result.json.dig("summary", "offense_count"), :>=, 1
      end

      def assert_cli_options_note(result, sources)
        expected = "#{NOTE_PREFIX}#{sources}#{NOTE_SUFFIX}"
        matches = result.stderr.lines.grep(/ignoring RuboCop CLI options/)
        assert_equal [expected], matches, failure_context(result)
        refute_includes result.stdout, "ignoring RuboCop CLI options", failure_context(result)
      end

      def assert_no_cli_options_note(result)
        refute_includes result.stderr, "ignoring RuboCop CLI options", failure_context(result)
        refute_includes result.stderr, "metz-scan: note:", failure_context(result)
      end

      def assert_offense_without_cli_note(result)
        assert_long_method_offense(result)
        assert_no_cli_options_note(result)
      end
    end

    # Proposal A: metz-scan ignores `.rubocop` and `RUBOCOP_OPTS` across all scan modes
    # and emits a single stderr note naming the ignored sources when non-empty.
    class ScanRubocopCliOptionsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanExitFixtures
      include ScanRubocopCliOptionsHelpers

      def test_default_scan_ignores_dot_rubocop_except_metz
        with_project("long.rb" => LONG_METHOD_RUBY, ".rubocop" => "--except Metz\n") do |dir|
          assert_long_method_offense(run_scan(dir, ".", "--format", "json"))
        end
      end

      def test_default_scan_ignores_dot_rubocop_display_only_correctable
        with_project("long.rb" => LONG_METHOD_RUBY, ".rubocop" => "--display-only-correctable\n") do |dir|
          assert_long_method_offense(run_scan(dir, ".", "--format", "json"))
        end
      end

      def test_default_scan_ignores_rubocop_opts_except_metz
        with_project("long.rb" => LONG_METHOD_RUBY) do |dir|
          assert_long_method_offense(run_scan(dir, ".", "--format", "json", rubocop_opts: "--except Metz"))
        end
      end

      def test_all_cops_scan_ignores_dot_rubocop_autocorrect_and_format
        with_project("fixable.rb" => FIXABLE_STOCK_RUBY, ".rubocop" => "--autocorrect\n--format simple\n") do |dir|
          assert_all_cops_unchanged_json(dir, run_scan(dir, ".", "--all-cops", "--format", "json"))
        end
      end

      def test_stderr_notes_dot_rubocop_once_across_scan_modes
        SCAN_MODES.each do |args|
          with_project("long.rb" => LONG_METHOD_RUBY, ".rubocop" => "--except Metz\n") do |dir|
            assert_cli_options_note(run_scan(dir, *args), ".rubocop")
          end
        end
      end

      def test_stderr_notes_rubocop_opts_when_only_rubocop_opts_is_set
        with_project("long.rb" => LONG_METHOD_RUBY) do |dir|
          result = run_scan(dir, ".", "--format", "json", rubocop_opts: "--except Metz")
          assert_cli_options_note(result, "RUBOCOP_OPTS")
          assert_equal 1, result.json.dig("summary", "offense_count")
        end
      end

      def test_stderr_notes_both_sources_when_both_are_present
        with_project("long.rb" => LONG_METHOD_RUBY, ".rubocop" => "--except Metz\n") do |dir|
          result = run_scan(dir, ".", "--format", "json", rubocop_opts: "--except Metz")
          assert_cli_options_note(result, ".rubocop and RUBOCOP_OPTS")
          assert_equal 1, result.json.dig("summary", "offense_count")
        end
      end

      def test_no_cli_options_note_when_neither_source_is_present
        with_project("long.rb" => LONG_METHOD_RUBY) do |dir|
          assert_offense_without_cli_note(run_scan(dir, ".", "--format", "json"))
        end
      end

      def test_no_cli_options_note_when_sources_are_empty_or_whitespace_only
        with_project("long.rb" => LONG_METHOD_RUBY, ".rubocop" => "  \n\t \n") do |dir|
          assert_offense_without_cli_note(run_scan(dir, ".", "--format", "json", rubocop_opts: ""))
          assert_offense_without_cli_note(run_scan(dir, ".", "--format", "json", rubocop_opts: "  \t\n "))
        end
      end

      def test_exit_2_reports_only_failure_without_cli_options_note
        with_project("a.rb" => CLEAN_RUBY, ".rubocop.yml" => BROKEN_CONFIG, ".rubocop" => "--except Metz\n") do |dir|
          result = run_scan(dir, ".", rubocop_opts: "--except Metz")
          assert_fails_closed(result, ".rubocop.yml")
          assert_no_cli_options_note(result)
        end
      end
    end
  end
end
