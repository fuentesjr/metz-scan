# frozen_string_literal: true

require "minitest/autorun"
require "rubocop"
require "stringio"
require "tmpdir"

require "metz_scan/cli"
require "support/scan_exit_fixtures"
require "support/scan_subprocess"

module MetzScan
  module Commands
    module ScanInProcessSupport
      Status = Struct.new(:exitstatus)

      def scan_subprocess(chdir, *args)
        out = StringIO.new
        err = StringIO.new
        status = run_cli_in_project(chdir, args, out, err)
        ScanSubprocessSupport::Result.new(out.string, err.string, Status.new(status))
      end

      private

      def run_cli_in_project(chdir, args, out, err)
        with_temp_rubocop_cache do
          Dir.chdir(chdir) do
            MetzScan::CLI.start(["scan", *args], stdout: out, stderr: err)
          ensure
            Scan::TargetFileDiscovery.reset_cwd_caches
          end
        end
      end

      def with_temp_rubocop_cache(&)
        Dir.mktmpdir("metz-scan-in-process-cache") do |cache_dir|
          with_rubocop_cache_root(cache_dir, &)
        end
      end

      def with_rubocop_cache_root(cache_dir)
        previous = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = cache_dir
        yield
      ensure
        restore_rubocop_cache_root(previous)
      end

      def restore_rubocop_cache_root(previous)
        if previous
          ENV["RUBOCOP_CACHE_ROOT"] = previous
        else
          ENV.delete("RUBOCOP_CACHE_ROOT")
        end
      end
    end

    # R4: a scan that checked no files is a failure to check, not a pass.
    class ScanExitNoFilesTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanInProcessSupport
      include ScanExitFixtures

      def test_default_scan_of_an_empty_directory_exits_2_saying_no_files_scanned
        with_project do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "no files scanned")
        end
      end

      def test_all_cops_scan_of_an_empty_directory_exits_2_saying_no_files_scanned
        with_project do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "no files scanned")
        end
      end

      def test_default_scan_exits_2_saying_no_files_scanned_when_the_project_excludes_every_ruby_file
        with_all_files_excluded do |dir|
          assert_exit_2_naming(scan_subprocess(dir, "."), "no files scanned")
        end
      end

      def test_all_cops_scan_exits_2_saying_no_files_scanned_when_the_project_excludes_every_ruby_file
        with_all_files_excluded do |dir|
          assert_exit_2_naming(scan_subprocess(dir, ".", "--all-cops"), "no files scanned")
        end
      end

      private

      def with_all_files_excluded(&)
        with_project("excluded/a.rb" => CLEAN_RUBY, ".rubocop.yml" => EXCLUDE_EVERYTHING_CONFIG, &)
      end
    end

    # Guards for the paths the exit-2 changes must not disturb: a clean scan still exits 0 and
    # a scan that only reports findings still exits 1. These pass before the change by design.
    class ScanExitSuccessPathsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanInProcessSupport
      include ScanExitFixtures

      # R6: RuboCop prints its pending-cops notice on stderr of clean runs; that notice is not an error.
      def test_a_clean_default_scan_still_exits_zero
        with_project("a.rb" => CLEAN_RUBY) do |dir|
          assert_clean_scan(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      # R6
      def test_a_clean_all_cops_scan_still_exits_zero
        with_project("a.rb" => CLEAN_RUBY_FOR_STOCK_COPS) do |dir|
          assert_clean_scan(scan_subprocess(dir, ".", "--all-cops", "--format", "json"))
        end
      end

      def test_a_scan_that_only_finds_offenses_still_exits_one
        with_project("many_params.rb" => TOO_MANY_PARAMETERS) do |dir|
          result = scan_subprocess(dir, ".", "--format", "json")

          assert_equal 1, result.exitstatus, failure_context(result)
          assert_equal ["Metz/MethodsTooManyParameters"], result.json.fetch("summary").fetch("offenses_by_cop").keys
        end
      end

      private

      def assert_clean_scan(result)
        assert_equal 0, result.exitstatus, failure_context(result)
        assert_equal 1, result.json.fetch("summary").fetch("inspected_file_count")
      end
    end

    # Exit status contract for `scan` (owner-approved 2026-10-13): RuboCop errors and
    # crashes exit 2 with the cause on stderr and nothing on stdout. RuboCop evaluates
    # ERB in `.rubocop.yml` before parsing it, so an ERB failure is a configuration
    # failure ("RuboCop failed: ..."), never an "internal error" with a backtrace, and
    # never exit 1 ("findings reported"). Observed 2026-10-14: a root `<% if %>` made
    # the default-mode scan crash with exit 1; `<%= no_such_helper %>` exited 2 but
    # was reported as an internal error with a Ruby backtrace.
    class ScanExitErbConfigTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanInProcessSupport
      include ScanExitFixtures

      ERB_SYNTAX_ERROR_CONFIG = "<% if %>\nAllCops:\n  SuggestExtensions: false\n"
      ERB_RUNTIME_ERROR_CONFIG = "AllCops:\n  TargetRubyVersion: <%= no_such_helper %>\n"
      VALID_CONFIG = "AllCops:\n  SuggestExtensions: false\n"

      CASES = {
        "a_root_config_with_an_erb_syntax_error" =>
          [{ ".rubocop.yml" => ERB_SYNTAX_ERROR_CONFIG, "a.rb" => CLEAN_RUBY }, "syntax"],
        "a_root_config_whose_erb_raises_at_runtime" =>
          [{ ".rubocop.yml" => ERB_RUNTIME_ERROR_CONFIG, "a.rb" => CLEAN_RUBY }, "no_such_helper"],
        "a_nested_config_with_an_erb_syntax_error" =>
          [{ ".rubocop.yml" => VALID_CONFIG, "a.rb" => CLEAN_RUBY, "sub/b.rb" => CLEAN_RUBY,
             "sub/.rubocop.yml" => ERB_SYNTAX_ERROR_CONFIG }, "syntax"]
      }.freeze

      CASES.each do |name, (files, cause)|
        define_method("test_default_scan_exits_2_as_a_configuration_failure_for_#{name}") do
          with_project(files) { |dir| assert_configuration_failure(scan_subprocess(dir, "."), cause) }
        end

        define_method("test_all_cops_scan_exits_2_as_a_configuration_failure_for_#{name}") do
          with_project(files) { |dir| assert_configuration_failure(scan_subprocess(dir, ".", "--all-cops"), cause) }
        end
      end

      private

      def assert_configuration_failure(result, cause)
        assert_fails_closed(result, cause)
        assert_includes result.stderr, "RuboCop failed", failure_context(result)
        refute_includes result.stderr, "internal error", failure_context(result)
        refute_match(/\.rb:\d+:in /, result.stderr, "expected no Ruby backtrace on stderr\n#{failure_context(result)}")
      end
    end

    # Directory scans check view templates (app/views), not every template in the tree.
    # Generator and config templates are not Ruby: reading them as Ruby reports Lint/Syntax
    # noise, and a project holding only such templates has had no code checked.
    # Owner-approved 2026-10-13 with the exit contract.
    class ScanExitTemplatesOutsideViewsTest < Minitest::Test
      include ScanSubprocessSupport
      include ScanInProcessSupport
      include ScanExitFixtures

      VIEW = "app/views/users/show.html.erb"
      SCAFFOLD_FORM = "lib/templates/erb/scaffold/_form.html.erb"
      TEMPLATES_OUTSIDE_VIEWS = {
        "config/nginx.conf.erb" => <<~TEMPLATE,
          server {
            listen <%= ENV.fetch("PORT", 80) %>;
            server_name <%= server_name %>;
            <% if ssl? %>
            ssl_certificate /etc/ssl/<%= server_name %>.crt;
            <% end %>
          }
        TEMPLATE
        "lib/generators/thing/templates/model.rb.erb" => <<~TEMPLATE,
          class <%= class_name %> < ApplicationRecord
          <% attributes.select(&:reference?).each do |attribute| -%>
            belongs_to :<%= attribute.name %>
          <% end -%>
          end
        TEMPLATE
        SCAFFOLD_FORM => <<~TEMPLATE,
          <%%= form_with(model: <%= model_resource_name %>) do |form| %>
            <%% <%= singular_table_name %>.errors.each do |error| %>
              <p><%%= error.full_message %></p>
            <%% end %>
          <%% end %>
        TEMPLATE
        "lib/templates/haml/scaffold/_form.html.haml" => <<~TEMPLATE
          = form_with model: @<%= singular_table_name %> do |form|
            .field
              = form.label :name
        TEMPLATE
      }.freeze

      def test_default_scan_exits_2_saying_no_files_scanned_when_the_only_file_is_a_template_outside_app_views
        with_scaffold_template_only do |dir|
          assert_fails_closed(scan_subprocess(dir, "."), "no files scanned")
        end
      end

      # Already holds: RuboCop's own discovery never sees ERB. Keeps --all-cops unchanged.
      def test_all_cops_scan_still_exits_2_saying_no_files_scanned_when_the_only_file_is_a_template_outside_app_views
        with_scaffold_template_only do |dir|
          assert_fails_closed(scan_subprocess(dir, ".", "--all-cops"), "no files scanned")
        end
      end

      def test_default_directory_scan_exits_0_without_syntax_offenses_when_templates_outside_app_views_are_not_ruby
        with_views_and_other_templates do |dir|
          result = scan_subprocess(dir, ".", "--format", "json")

          assert_equal 0, result.exitstatus, failure_context(result)
          assert_equal [], offense_cop_names(result), failure_context(result)
        end
      end

      def test_default_directory_scan_inspects_the_view_but_none_of_the_templates_outside_app_views
        with_views_and_other_templates do |dir|
          paths = inspected_paths(scan_subprocess(dir, ".", "--format", "json"))

          assert_includes paths, VIEW
          assert_empty paths & TEMPLATES_OUTSIDE_VIEWS.keys
        end
      end

      # Already holds: guards RuboCop's own file discovery staying unchanged.
      def test_all_cops_directory_scan_exits_0_without_syntax_offenses_on_the_same_project
        with_views_and_other_templates do |dir|
          result = scan_subprocess(dir, ".", "--all-cops", "--format", "json")

          assert_equal 0, result.exitstatus, failure_context(result)
          assert_equal [], offense_cop_names(result), failure_context(result)
        end
      end

      private

      def with_scaffold_template_only(&)
        with_project(SCAFFOLD_FORM => TEMPLATES_OUTSIDE_VIEWS.fetch(SCAFFOLD_FORM), &)
      end

      def with_views_and_other_templates(&)
        with_project(TEMPLATES_OUTSIDE_VIEWS.merge("ok.rb" => CLEAN_RUBY, VIEW => CLEAN_ERB_VIEW), &)
      end

      def inspected_paths(result)
        result.json.fetch("files").map { |file| file.fetch("path").delete_prefix("./") }
      end

      def offense_cop_names(result)
        offenses = result.json.fetch("files").flat_map { |file| file.fetch("offenses") }
        offenses.map { |offense| offense.fetch("cop_name") }
      end
    end
  end
end
