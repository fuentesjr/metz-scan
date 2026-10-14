# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Shared project builder and scan runner for the default-scan tests of the
    # rails-aware cops.
    module RailsAwareScanProject
      CONTROLLERS_COP = "Metz/ControllersTooManyDirectCollaborators"
      VIEWS_COP = "Metz/ViewsDeepNavigation"
      # Two distinct collaborators; the cop's default MaxCollaborators is 1.
      CONTROLLER_SOURCE = <<~RUBY
        class ReportsController < ApplicationController
          def show
            User.find(1)
            AuditLog.recent
          end
        end
      RUBY
      # A four-link chain; the cop's default MaxChainLength is 3.
      VIEW_SOURCE = "<%= user.account.owner.email %>\n"
      CONTROLLERS = {
        cop: CONTROLLERS_COP,
        app: "app/controllers/reports_controller.rb",
        engine: "engines/x/app/controllers/reports_controller.rb",
        legacy_app: "app/controllers/legacy_controller.rb",
        legacy_engine: "engines/x/app/controllers/legacy_controller.rb",
        default_include: "app/controllers/**/*.rb",
        source: CONTROLLER_SOURCE,
        scan_by: :directory
      }.freeze
      # The base default scan does not pick up view templates from a directory
      # scan, so the templates are passed on the command line.
      VIEWS = {
        cop: VIEWS_COP,
        app: "app/views/v/show.html.erb",
        engine: "engines/x/app/views/v/show.html.erb",
        legacy_app: "app/views/v/legacy.html.erb",
        legacy_engine: "engines/x/app/views/v/legacy.html.erb",
        default_include: "app/views/**/*.{erb,haml,slim}",
        source: VIEW_SOURCE,
        scan_by: :files
      }.freeze

      def setup
        @project = Dir.mktmpdir("metz-scan-rails-aware-include-test")
      end

      def teardown
        FileUtils.remove_entry(@project)
      end

      def merged_include(scope)
        "#{scope.fetch(:cop)}:\n  inherit_mode:\n    merge:\n      - Include\n  Include:\n    - 'lib/**/*'\n"
      end

      def listed_include(scope)
        "#{scope.fetch(:cop)}:\n  Include:\n    - '#{scope.fetch(:default_include)}'\n    - 'lib/**/*'\n"
      end

      def replacing_include(scope)
        "#{scope.fetch(:cop)}:\n  Include:\n    - 'lib/**/*'\n"
      end

      # Writes the project, runs the default scan, and returns the exit status
      # with the sorted paths the scope's cop flagged.
      def scan_flagged(scope, config, file_keys)
        write_file(".rubocop.yml", config)
        paths = file_keys.map { |key| scope.fetch(key) }
        paths.each { |path| write_file(path, scope.fetch(:source)) }
        stdout, stderr, status = scan_subprocess(scope.fetch(:scan_by) == :directory ? ["."] : paths)
        [status.exitstatus, flagged_paths(stdout, scope.fetch(:cop), stderr)]
      end

      def flagged_paths(stdout, cop, stderr)
        files = JSON.parse(stdout).fetch("files")
        files.select { |file| file.fetch("offenses").any? { |o| o.fetch("cop_name") == cop } }
             .map { |file| file.fetch("path") }.sort
      rescue JSON::ParserError
        flunk "scan did not print JSON; stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      end

      def write_file(relative_path, contents)
        path = File.join(@project, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end

      def scan_subprocess(targets)
        Open3.capture3(
          subprocess_env,
          "bundle", "exec", RbConfig.ruby, File.join(repo_root, "bin/metz-scan"), "scan", *targets,
          "--format", "json", chdir: @project
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

    # Metz/ControllersTooManyDirectCollaborators and Metz/ViewsDeepNavigation
    # check controllers and views under app/ and under nested app roots (engines,
    # packs) by default. Owner decision 2026-10-13: a project's per-cop Include
    # that still lists the default pattern (via `inherit_mode: merge: [Include]`
    # or listed explicitly) keeps that scope and adds its extra paths; an Include
    # without the default pattern replaces the scope. Plain RuboCop and
    # `--all-cops` already behave this way
    # (rubocop-metz/test/integration/rails_aware_cops_fixture_integration_test.rb);
    # these tests pin the default (Metz-only) scan.
    #
    # Every scan runs as a subprocess from the project root: default mode matches
    # the cops' app/-anchored globs relative to the current directory. Nothing
    # here asserts on files under the extra path (lib/**); the default scan does
    # not check them yet and a separate item tracks that.
    class ScanRailsAwareIncludeTest < Minitest::Test
      include RailsAwareScanProject

      # Requirement 1.
      def test_controllers_cop_with_merged_include_reports_app_and_engine_controllers
        assert_app_and_engine_reported(CONTROLLERS, merged_include(CONTROLLERS), "merged Include (req 1)")
      end

      def test_views_cop_with_merged_include_reports_app_and_engine_views
        assert_app_and_engine_reported(VIEWS, merged_include(VIEWS), "merged Include (req 1)")
      end

      # Requirement 2.
      def test_controllers_cop_with_default_pattern_listed_explicitly_reports_app_and_engine_controllers
        assert_app_and_engine_reported(CONTROLLERS, listed_include(CONTROLLERS), "explicit default Include (req 2)")
      end

      def test_views_cop_with_default_pattern_listed_explicitly_reports_app_and_engine_views
        assert_app_and_engine_reported(VIEWS, listed_include(VIEWS), "explicit default Include (req 2)")
      end

      # Requirement 3. The owner has not yet designed how the default scan honors
      # an Include that replaces the default. Until then the scan keeps checking
      # the stock scope and must never come back clean for this project.
      def test_controllers_cop_with_replacing_include_still_reports_stock_scope_instead_of_a_clean_result
        assert_app_and_engine_reported(CONTROLLERS, replacing_include(CONTROLLERS), "replacing Include (req 3)")
      end

      def test_views_cop_with_replacing_include_still_reports_stock_scope_instead_of_a_clean_result
        assert_app_and_engine_reported(VIEWS, replacing_include(VIEWS), "replacing Include (req 3)")
      end

      private

      def assert_app_and_engine_reported(scope, config, label)
        status, flagged = scan_flagged(scope, config, %i[app engine])

        assert_equal [scope.fetch(:app), scope.fetch(:engine)].sort, flagged,
                     "#{label}: #{scope.fetch(:cop)} must report the app and the engine file"
        assert_equal 1, status, "#{label}: scan must exit 1 (findings reported), not 0 or a crash"
      end
    end

    class ScanRailsAwareExcludeTest < Minitest::Test
      include RailsAwareScanProject

      # Requirement 4. Not covered for these cops in the default scan before this
      # file: the existing default-scan Exclude tests in scan_test.rb use
      # Metz/MethodsTooLong, and the rails-aware integration test runs plain RuboCop.
      def test_controllers_cop_exclude_drops_matching_files_and_reports_the_rest
        assert_exclude_drops_matching_files(CONTROLLERS)
      end

      def test_views_cop_exclude_drops_matching_files_and_reports_the_rest
        assert_exclude_drops_matching_files(VIEWS)
      end

      private

      def assert_exclude_drops_matching_files(scope)
        config = "#{scope.fetch(:cop)}:\n  Exclude:\n    - '**/legacy*'\n"
        status, flagged = scan_flagged(scope, config, %i[app engine legacy_app legacy_engine])

        assert_equal [scope.fetch(:app), scope.fetch(:engine)].sort, flagged,
                     "req 4: per-cop Exclude must drop only the matching files for #{scope.fetch(:cop)}"
        assert_equal 1, status, "req 4: the files that are not excluded are still reported (exit 1)"
      end
    end
  end
end
