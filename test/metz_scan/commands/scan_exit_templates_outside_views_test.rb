# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_exit_fixtures"
require "support/scan_subprocess"

# Directory scans check view templates (app/views), not every template in the tree.
# Generator and config templates are not Ruby: reading them as Ruby reports Lint/Syntax
# noise, and a project holding only such templates has had no code checked.
# Owner-approved 2026-10-13 with the exit contract.
module MetzScan
  module Commands
    class ScanExitTemplatesOutsideViewsTest < Minitest::Test
      include ScanSubprocessSupport
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

      def test_auto_fix_exits_2_saying_no_files_scanned_when_the_only_file_is_a_template_outside_app_views
        with_scaffold_template_only do |dir|
          assert_fails_closed(scan_subprocess(dir, ".", "--auto-fix"), "no files scanned")
        end
      end

      def test_auto_fix_all_cops_exits_2_saying_no_files_scanned_when_the_only_file_is_a_template_outside_app_views
        with_scaffold_template_only do |dir|
          assert_fails_closed(scan_subprocess(dir, ".", "--auto-fix", "--all-cops"), "no files scanned")
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
