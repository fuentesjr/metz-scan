# frozen_string_literal: true

require "minitest/autorun"

require "support/scan_subprocess"

# Spec tests for Proposal B: per-cop `Include` widening and replacement in the
# default (Metz-only) scan, `--all-cops`, suppression ledger, and nested
# `.rubocop.yml` inheritance.
module MetzScan
  module Commands
    module WidenedIncludeScanSupport
      include ScanSubprocessSupport

      VIEWS_COP = "Metz/ViewsDeepNavigation"
      OPS_COP = "Metz/OperationsTooManyPublicMethods"
      DEEP_ERB = "<%= user.account.owner.email %>\n"
      DEEP_HAML = "%p\n  = user.account.owner.email\n"
      DEEP_SLIM = "p\n  = user.account.owner.email\n"

      def two_public_methods_class(name)
        "# frozen_string_literal: true\n\n# #{name}.\nclass #{name}\n  " \
          "def call; end\n\n  def undo; end\nend\n"
      end

      def merged_views_config(pattern)
        "#{VIEWS_COP}:\n  inherit_mode:\n    merge:\n      - Include\n  Include:\n    - \"#{pattern}\"\n"
      end

      def merged_ops_config(header = "")
        "#{header}#{OPS_COP}:\n  inherit_mode:\n    merge:\n      - Include\n  " \
          "Include:\n    - \"app/commands/**/*.rb\"\n"
      end

      def offense_cops_by_path(result)
        result.json.fetch("files").to_h { |file| [file.fetch("path").delete_prefix("./"), cop_names(file)] }
              .reject { |_path, cops| cops.empty? }
      end

      def cop_names(file_entry)
        file_entry.fetch("offenses").map { |offense| offense.fetch("cop_name") }
      end

      def inspected_paths(result)
        result.json.fetch("files").map { |file| file.fetch("path").delete_prefix("./") }
      end

      def all_offense_cops(result)
        result.json.fetch("files").flat_map { |file| cop_names(file) }
      end

      def assert_reports_cops(result, expected)
        assert_equal 1, result.exitstatus, failure_context(result)
        assert_equal expected, offense_cops_by_path(result), failure_context(result)
      end

      def assert_no_suppressions(result)
        assert_equal [], result.json.fetch("suppressions"), failure_context(result)
      end
    end

    class ScanWidenedViewTemplatesTest < Minitest::Test
      include WidenedIncludeScanSupport

      COMPONENT_GLOB = "app/components/**/*.{erb,haml,slim}"

      def test_merged_include_reports_views_deep_navigation_on_app_views_and_view_components
        with_project(widened_component_templates) do |dir|
          assert_reports_cops(scan_subprocess(dir, ".", "--format", "json"), expected_component_and_view_cops)
        end
      end

      def test_broad_widened_include_glob_ignores_non_template_assets
        with_project(broad_glob_component_files) do |dir|
          assert_clean_single_template_scan(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      def test_replacing_views_include_skips_app_views_and_exits_two_when_no_matching_files_exist
        files = { ".rubocop.yml" => "#{VIEWS_COP}:\n  Include:\n    - \"app/components/**/*.erb\"\n",
                  "app/views/users/show.html.erb" => DEEP_ERB }
        with_project(files) { |dir| assert_fails_closed(scan_subprocess(dir, "."), "no files scanned") }
      end

      private

      def widened_component_templates
        { ".rubocop.yml" => merged_views_config(COMPONENT_GLOB),
          "app/views/users/show.html.erb" => DEEP_ERB, "app/components/card_component.html.erb" => DEEP_ERB,
          "app/components/badge_component.html.haml" => DEEP_HAML,
          "app/components/modal_component.html.slim" => DEEP_SLIM }
      end

      def expected_component_and_view_cops
        { "app/components/badge_component.html.haml" => [VIEWS_COP],
          "app/components/card_component.html.erb" => [VIEWS_COP],
          "app/components/modal_component.html.slim" => [VIEWS_COP],
          "app/views/users/show.html.erb" => [VIEWS_COP] }
      end

      def broad_glob_component_files
        { ".rubocop.yml" => merged_views_config("app/components/**/*"),
          "app/components/card.html.erb" => "<%= user.name %>\n",
          "app/components/card.js" => "export default () => { const x = 1; };\n",
          "app/components/card.css" => ".card { color: red; }\n" }
      end

      def assert_clean_single_template_scan(result)
        assert_equal 0, result.exitstatus, failure_context(result)
        assert_equal 1, result.json.dig("summary", "inspected_file_count"), failure_context(result)
        assert_equal ["app/components/card.html.erb"], inspected_paths(result), failure_context(result)
        assert_equal [], all_offense_cops(result), failure_context(result)
      end
    end

    class ScanWidenedOperationsIncludeTest < Minitest::Test
      include WidenedIncludeScanSupport

      ALL_COPS_HEADER = "AllCops:\n  NewCops: disable\n  SuggestExtensions: false\n\n"

      def test_merged_operations_include_reports_services_and_commands_in_default_and_all_cops
        with_project(merged_operations_project) do |dir|
          assert_default_and_all_cops_report_both(dir)
        end
      end

      def test_replacing_operations_include_drops_services_and_reports_only_commands
        config = "#{OPS_COP}:\n  Include:\n    - \"app/commands/**/*.rb\"\n"
        with_project(operations_files(config)) do |dir|
          assert_only_commands_reported(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      def test_nested_rubocop_yml_inherits_widened_include_from_parent_config
        with_project(nested_operations_project) do |dir|
          assert_only_commands_reported(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      private

      def merged_operations_project
        operations_files(merged_ops_config(ALL_COPS_HEADER))
      end

      def nested_operations_project
        { ".rubocop.yml" => merged_ops_config,
          "app/commands/.rubocop.yml" => "inherit_from: ../../.rubocop.yml\n",
          "app/commands/charge_order.rb" => two_public_methods_class("ChargeOrder") }
      end

      def operations_files(config)
        { ".rubocop.yml" => config,
          "app/services/billing.rb" => two_public_methods_class("Billing"),
          "app/commands/charge_order.rb" => two_public_methods_class("ChargeOrder") }
      end

      def assert_only_commands_reported(result)
        assert_reports_cops(result, { "app/commands/charge_order.rb" => [OPS_COP] })
        assert_no_suppressions(result)
      end

      def assert_default_and_all_cops_report_both(dir)
        expected = { "app/commands/charge_order.rb" => [OPS_COP], "app/services/billing.rb" => [OPS_COP] }
        default_result = scan_subprocess(dir, ".", "--format", "json")
        assert_reports_cops(default_result, expected)
        assert_no_suppressions(default_result)
        assert_all_cops_reports_ops_on_both(scan_subprocess(dir, ".", "--all-cops", "--format", "json"))
      end

      def assert_all_cops_reports_ops_on_both(result)
        assert_equal 1, result.exitstatus, failure_context(result)
        cops = offense_cops_by_path(result)
        assert_includes cops["app/services/billing.rb"], OPS_COP, failure_context(result)
        assert_includes cops["app/commands/charge_order.rb"], OPS_COP, failure_context(result)
      end
    end

    class ScanWidenedIncludeLedgerTest < Minitest::Test
      include WidenedIncludeScanSupport

      LEGACY_COMPONENT = "app/components/legacy_component.html.erb"
      CONFIG_EXCLUDE_YAML = <<~YAML
        Metz/ViewsDeepNavigation:
          inherit_mode:
            merge:
              - Include
          Include:
            - "app/components/**/*.erb"
          Exclude:
            - "app/components/legacy_component.html.erb" # legacy view component
      YAML
      CONFIG_DISABLED_YAML = <<~YAML
        Metz/ViewsDeepNavigation:
          Enabled: false # migrating components
          inherit_mode:
            merge:
              - Include
          Include:
            - "app/components/**/*.erb"
      YAML
      STOCK_EXCLUDE_WITH_REASON_YAML = <<~YAML
        Metz/DemeterTrainWreck:
          Exclude:
            - "spec/**/*" # specs build deep fixtures
            - "db/migrate/**/*" # legacy migrations
      YAML
      DEEP_SPEC_CHAIN = "# frozen_string_literal: true\n\nuser.account.subscription.plan.name\n"

      def test_config_exclude_records_widened_component_in_suppression_ledger
        with_project(excluded_component_project) do |dir|
          assert_config_exclude_ledger(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      def test_config_disabled_records_widened_component_in_suppression_ledger
        files = { ".rubocop.yml" => CONFIG_DISABLED_YAML, "app/components/card_component.html.erb" => DEEP_ERB }
        with_project(files) do |dir|
          assert_config_disabled_ledger(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      def test_explicit_stock_exclude_pattern_with_reason_is_recorded_in_suppression_ledger
        files = { ".rubocop.yml" => STOCK_EXCLUDE_WITH_REASON_YAML, "spec/user_spec.rb" => DEEP_SPEC_CHAIN }
        with_project(files) do |dir|
          assert_stock_exclude_ledger(scan_subprocess(dir, ".", "--format", "json"))
        end
      end

      private

      def assert_stock_exclude_ledger(result)
        assert_equal 0, result.exitstatus, failure_context(result)
        assert_equal({}, offense_cops_by_path(result), failure_context(result))
        assert_equal [expected_stock_exclude_summary], suppression_summaries(result), failure_context(result)
      end

      def excluded_component_project
        { ".rubocop.yml" => CONFIG_EXCLUDE_YAML,
          "app/components/card_component.html.erb" => DEEP_ERB,
          LEGACY_COMPONENT => DEEP_ERB }
      end

      def assert_config_exclude_ledger(result)
        assert_reports_cops(result, { "app/components/card_component.html.erb" => [VIEWS_COP] })
        assert_equal [expected_exclude_summary], suppression_summaries(result), failure_context(result)
      end

      def assert_config_disabled_ledger(result)
        assert_equal 0, result.exitstatus, failure_context(result)
        assert_equal({}, offense_cops_by_path(result), failure_context(result))
        assert_equal [expected_disabled_summary], suppression_summaries(result), failure_context(result)
      end

      def suppression_summaries(result)
        keys = %w[cop_name path suppressed_by reason reason_status config]
        result.json.fetch("suppressions").map { |record| record.slice(*keys) }
      end

      def expected_exclude_summary
        { "cop_name" => VIEWS_COP, "path" => LEGACY_COMPONENT,
          "suppressed_by" => "config_exclude", "reason" => "legacy view component", "reason_status" => "present",
          "config" => { "path" => ".rubocop.yml", "line" => 8, "pattern" => LEGACY_COMPONENT } }
      end

      def expected_disabled_summary
        { "cop_name" => VIEWS_COP, "path" => "app/components/card_component.html.erb",
          "suppressed_by" => "config_disabled", "reason" => "migrating components", "reason_status" => "present",
          "config" => { "path" => ".rubocop.yml", "line" => 2 } }
      end

      def expected_stock_exclude_summary
        { "cop_name" => "Metz/DemeterTrainWreck", "path" => "spec/user_spec.rb",
          "suppressed_by" => "config_exclude", "reason" => "specs build deep fixtures", "reason_status" => "present",
          "config" => { "path" => ".rubocop.yml", "line" => 3, "pattern" => "spec/**/*" } }
      end
    end
  end
end
