# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Default mode runs --force-default-config, so app/-anchored cop Include
    # globs resolve against the current directory; files they would match from
    # their project root silently lose those cops, and the scan says so on stderr.
    class ScanPathScopedIncludeNoteTest < Minitest::Test
      OPERATION_FIXTURE = <<~RUBY
        # frozen_string_literal: true

        class Foo
          def a; end

          def b; end
        end
      RUBY
      FIXTURE_FILES = %w[base/app/operations/foo.rb other/app/operations/bar.rb other/app/operations/baz.rb
                         host/engines/billing/app/controllers/x_controller.rb libonly/lib/foo.rb].freeze
      NOTE_PATTERN = /path-scoped cops/
      OPERATIONS_EXAMPLE = "Metz/OperationsTooManyPublicMethods matches app/operations/**/*.rb " \
                           "relative to the current directory"

      def setup
        @root = Dir.mktmpdir("metz-scan-path-scoped-include-note-test")
        @parent = File.join(@root, "parent")
        @project = File.join(@parent, "base")
        @elsewhere = File.join(@root, "elsewhere")
        write_fixtures
      end

      def teardown
        FileUtils.remove_entry(@root)
      end

      def test_default_scan_notes_project_subdirectory_scanned_from_parent
        stdout, stderr, status = scan_subprocess(@parent, "base")

        assert_findings_unchanged_and_dropped(stdout, stderr, status)
        assert_equal ["#{expected_note('base')}\n"], note_lines(stderr)
      end

      def test_default_scan_notes_path_outside_current_directory
        stdout, stderr, status = scan_subprocess(@elsewhere, @project)

        assert_findings_unchanged_and_dropped(stdout, stderr, status)
        assert_equal ["#{expected_note(@project)}\n"], note_lines(stderr)
      end

      def test_default_scan_names_every_root_with_missed_files_in_one_note
        stdout, stderr, status = scan_subprocess(@parent, "base", "other")

        assert_findings_unchanged_and_dropped(stdout, stderr, status)
        assert_equal ["metz-scan: note: path-scoped cops did not check 3 files under base, other " \
                      "(#{OPERATIONS_EXAMPLE}); scan each root from inside it to check them\n"], note_lines(stderr)
      end

      # Nested app trees (engines, spec/dummy) are truthfully reported, but the
      # remedy must not read as "scan only the engine instead".
      def test_default_scan_notes_nested_engine_without_redirecting_whole_scan
        _stdout, stderr, _status = scan_subprocess(File.join(@parent, "host"), ".")

        assert_equal ["metz-scan: note: path-scoped cops did not check 1 file under engines/billing " \
                      "(Metz/ControllersTooManyDirectCollaborators matches app/controllers/**/*.rb relative to the " \
                      "current directory); scan engines/billing from inside it to check them\n"], note_lines(stderr)
      end

      def test_default_scan_has_no_note_from_project_root
        [".", "app"].each do |path|
          stdout, stderr, status = scan_subprocess(@project, path)

          assert_equal 1, status.exitstatus, stdout + stderr
          assert_equal [], note_lines(stderr), path
        end
      end

      def test_default_scan_has_no_note_without_path_scoped_files
        stdout, stderr, status = scan_subprocess(@parent, "libonly")

        assert_operator status.exitstatus, :<, 2, stdout + stderr
        assert_equal [], note_lines(stderr)
      end

      def test_all_cops_scan_has_no_note
        _stdout, stderr, _status = scan_subprocess(@parent, "base", "--all-cops")

        assert_equal [], note_lines(stderr)
      end

      private

      def assert_findings_unchanged_and_dropped(stdout, stderr, status)
        assert_equal 0, status.exitstatus, stdout + stderr
        assert_equal [], JSON.parse(stdout).fetch("files").flat_map { |file| file.fetch("offenses") },
                     "path-scoped findings stay dropped; only the note is new"
      end

      def expected_note(root)
        "metz-scan: note: path-scoped cops did not check 1 file under #{root} (#{OPERATIONS_EXAMPLE}); " \
          "scan #{root} from inside it to check them"
      end

      def note_lines(stderr)
        stderr.lines.grep(NOTE_PATTERN)
      end

      def write_fixtures
        FIXTURE_FILES.each { |relative_path| write_file(relative_path) }
        FileUtils.mkdir_p(@elsewhere)
      end

      def write_file(relative_path)
        path = File.join(@parent, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, OPERATION_FIXTURE)
      end

      def scan_subprocess(dir, path, *flags)
        Open3.capture3(
          subprocess_env,
          "bundle", "exec", RbConfig.ruby, File.join(repo_root, "bin/metz-scan"), "scan", path, *flags,
          "--format", "json", chdir: dir
        )
      end

      def subprocess_env
        {
          "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil
        }
      end

      def repo_root
        File.expand_path("../../..", __dir__)
      end
    end
  end
end
