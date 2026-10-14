# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_subprocess"

# A directory scan must check view templates under app/views/ the same way an
# explicitly passed template file is checked. Owner-approved 2026-10-13 as part of
# closing every path where `scan` passes without checking the code.
module MetzScan
  module Commands
    class ScanDirectoryViewTemplatesTest < Minitest::Test
      include ScanSubprocessSupport

      DEEP_CHAIN = "@user.account.owner.profile.name"
      ERB_TEMPLATE = "<%= #{DEEP_CHAIN} %>\n".freeze
      HAML_TEMPLATE = "%p\n  = #{DEEP_CHAIN}\n".freeze
      SLIM_TEMPLATE = "p\n  = #{DEEP_CHAIN}\n".freeze
      ERB_PATH = "app/views/users/show.html.erb"
      DEEP_NAVIGATION = "Metz/ViewsDeepNavigation"

      def test_scanning_the_app_root_directory_reports_deep_navigation_in_an_erb_template
        with_project(ERB_PATH => ERB_TEMPLATE) do |dir|
          assert_reports_only_deep_navigation(scan_subprocess(dir, ".", "--format", "json"), ERB_PATH)
        end
      end

      def test_scanning_the_app_directory_reports_deep_navigation_in_an_erb_template
        with_project(ERB_PATH => ERB_TEMPLATE) do |dir|
          assert_reports_only_deep_navigation(scan_subprocess(dir, "app", "--format", "json"), ERB_PATH)
        end
      end

      def test_scanning_the_views_directory_reports_deep_navigation_in_an_erb_template
        with_project(ERB_PATH => ERB_TEMPLATE) do |dir|
          assert_reports_only_deep_navigation(scan_subprocess(dir, "app/views", "--format", "json"), ERB_PATH)
        end
      end

      def test_scanning_a_directory_reports_deep_navigation_in_a_haml_template
        path = "app/views/users/show.html.haml"
        with_project(path => HAML_TEMPLATE) do |dir|
          assert_reports_only_deep_navigation(scan_subprocess(dir, "app", "--format", "json"), path)
        end
      end

      def test_scanning_a_directory_reports_deep_navigation_in_a_slim_template
        path = "app/views/users/show.html.slim"
        with_project(path => SLIM_TEMPLATE) do |dir|
          assert_reports_only_deep_navigation(scan_subprocess(dir, "app", "--format", "json"), path)
        end
      end

      def test_a_directory_scan_reports_the_same_offense_as_passing_the_template_file_explicitly
        with_project(ERB_PATH => ERB_TEMPLATE) do |dir|
          from_file = offenses_by_path(scan_subprocess(dir, ERB_PATH, "--format", "json"))

          refute_empty from_file.fetch(ERB_PATH), "explicit template scan should report the deep chain"
          assert_equal from_file, offenses_by_path(scan_subprocess(dir, "app", "--format", "json"))
        end
      end

      def test_a_directory_scan_still_applies_the_project_exclude_to_view_templates
        with_one_excluded_template do |dir|
          result = scan_subprocess(dir, ".", "--format", "json")

          assert_reports_only_deep_navigation(result, "app/views/users/index.html.erb")
          refute_includes offenses_by_path(result).keys, "app/views/users/show.html.erb"
        end
      end

      private

      def with_one_excluded_template(&)
        config = "AllCops:\n  Exclude:\n    - 'app/views/users/show.html.erb'\n"
        files = { "app/views/users/show.html.erb" => ERB_TEMPLATE, "app/views/users/index.html.erb" => ERB_TEMPLATE,
                  ".rubocop.yml" => config }
        with_project(files, &)
      end

      def assert_reports_only_deep_navigation(result, template_path)
        assert_equal 1, result.exitstatus, failure_context(result)
        assert_equal({ template_path => [DEEP_NAVIGATION] }, offense_cops_by_path(result), failure_context(result))
      end

      def offense_cops_by_path(result)
        offenses_by_path(result).transform_values { |offenses| offenses.map { |offense| offense.fetch("cop_name") } }
                                .reject { |_path, cops| cops.empty? }
      end

      def offenses_by_path(result)
        result.json.fetch("files").to_h do |file|
          [file.fetch("path").delete_prefix("./"), file.fetch("offenses")]
        end
      end
    end
  end
end
