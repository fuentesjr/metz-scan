# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Spec tests for RuboCop `inherit_mode` handling in the default (Metz-only)
    # scan and its suppression ledger.
    module InheritModeScanSupport
      LONG = "Metz/MethodsTooLong"
      OPS = "Metz/OperationsTooManyPublicMethods"
      LONG_MESSAGE = "Metz/MethodsTooLong: Method `m` has too many lines. [6/5]"

      def self.long_class(name)
        <<~RUBY
          # frozen_string_literal: true

          # Sample #{name}.
          class #{name}
            def m
              a = 1
              b = 2
              c = 3
              d = 4
              e = 5
              [a, b, c, d, e]
            end
          end
        RUBY
      end

      def setup
        @project = Dir.mktmpdir("metz-scan-inherit-mode")
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      private

      def write_project(files)
        files.each { |path, body| write_file(path, body) }
      end

      def write_file(path, body)
        full_path = File.join(@project, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, body)
      end

      def scan_json(*)
        stdout, stderr, @status = scan(*, "--format", "json")
        JSON.parse(stdout)
      rescue JSON::ParserError
        flunk "scan did not emit JSON (exit #{@status&.exitstatus}): #{stderr}"
      end

      def scan(*)
        Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, bin_path, "scan", *, chdir: @project)
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def bin_path = File.join(repo_root, "bin/metz-scan")
      def repo_root = File.expand_path("../../..", __dir__)

      def live_offenses(json)
        json.fetch("files").flat_map do |file|
          file.fetch("offenses").map { |offense| [file.fetch("path"), offense.fetch("cop_name")] }
        end
      end

      def exclude_record(path, config_path, config_line, reason)
        pattern = path.start_with?("legacy/") ? "legacy/**/*" : "vendor_port/**/*"
        { "cop_name" => LONG, "path" => path, "line" => 5, "column" => 3, "message" => LONG_MESSAGE,
          "suppressed_by" => "config_exclude", "reason" => reason, "reason_status" => "present",
          "directive" => nil, "config" => { "path" => config_path, "line" => config_line, "pattern" => pattern } }
      end
    end

    class ScanInheritModeIncludeTest < Minitest::Test
      include InheritModeScanSupport

      FIXTURES = {
        ".rubocop.yml" => <<~YAML,
          Metz/OperationsTooManyPublicMethods:
            inherit_mode:
              merge:
                - Include
            Include:
              - "lib/**/*"
        YAML
        "app/services/billing.rb" => <<~RUBY
          # frozen_string_literal: true

          # Billing service.
          class Billing
            def call
              :ok
            end

            def refund
              :ok
            end
          end
        RUBY
      }.freeze

      def test_per_cop_inherit_mode_merge_include_preserves_stock_scope
        write_project(FIXTURES)
        assert_default_ops_reported(scan_json("."))
        assert_includes live_offenses(scan_json(".", "--all-cops")), ["app/services/billing.rb", OPS]
        assert_equal 1, @status.exitstatus
      end

      private

      def assert_default_ops_reported(json)
        assert_equal [1, 1, []],
                     [@status.exitstatus, json.dig("summary", "offense_count"), json.fetch("suppressions")]
        assert_equal [["app/services/billing.rb", OPS]], live_offenses(json)
      end
    end

    class ScanInheritModeExcludeTest < Minitest::Test
      include InheritModeScanSupport

      BASE_EXCLUDE = <<~YAML
        Metz/MethodsTooLong:
          Exclude:
            - "legacy/**/*" # legacy reason
      YAML
      BASE_WITH_MERGE = <<~YAML
        inherit_mode:
          merge:
            - Exclude
        Metz/MethodsTooLong:
          Exclude:
            - "legacy/**/*" # legacy reason
      YAML
      PORT_EXCLUDE = "  Exclude:\n    - \"vendor_port/**/*\" # port reason\n"
      PER_COP_MERGE_CONFIG = <<~YAML.freeze
        inherit_from: base.yml
        Metz/MethodsTooLong:
          inherit_mode:
            merge:
              - Exclude
        #{PORT_EXCLUDE}
      YAML
      PER_COP_OVERRIDE_CONFIG = <<~YAML.freeze
        inherit_from: base.yml
        inherit_mode:
          merge:
            - Exclude
        Metz/MethodsTooLong:
          inherit_mode:
            override:
              - Exclude
        #{PORT_EXCLUDE}
      YAML
      INHERITED_MERGE_CONFIG = <<~YAML.freeze
        inherit_from: base.yml
        AllCops:
          NewCops: disable
        Metz/MethodsTooLong:
        #{PORT_EXCLUDE}
      YAML
      ALL_COPS_BASE_EXCLUDE = <<~YAML
        AllCops:
          Exclude:
            - "legacy/**/*"
      YAML
      ALL_COPS_MERGE_CONFIG = <<~YAML.freeze
        inherit_from: base.yml
        AllCops:
          inherit_mode:
            merge:
              - Exclude
        #{PORT_EXCLUDE}
      YAML
      SOURCE_FILES = {
        "legacy/old.rb" => InheritModeScanSupport.long_class("Old"),
        "vendor_port/port.rb" => InheritModeScanSupport.long_class("Port")
      }.freeze

      def test_per_cop_inherit_mode_merge_exclude_unions_inherited_and_local_excludes
        write_project(SOURCE_FILES.merge("base.yml" => BASE_EXCLUDE, ".rubocop.yml" => PER_COP_MERGE_CONFIG))
        assert_both_suppressed(scan_json("."), base_line: 3, project_line: 7)
      end

      def test_per_cop_inherit_mode_override_exclude_overrides_top_level_merge
        write_project(SOURCE_FILES.merge("base.yml" => BASE_EXCLUDE, ".rubocop.yml" => PER_COP_OVERRIDE_CONFIG))
        assert_only_vendor_port_suppressed(scan_json("."))
      end

      def test_inherit_mode_merge_exclude_declared_in_inherited_base_config
        write_project(SOURCE_FILES.merge("base.yml" => BASE_WITH_MERGE, ".rubocop.yml" => INHERITED_MERGE_CONFIG))
        assert_both_suppressed(scan_json("."), base_line: 6, project_line: 6)
        all_cops = scan_json(".", "--all-cops")
        assert_equal [0, 0], [@status.exitstatus, all_cops.dig("summary", "offense_count")]
      end

      def test_all_cops_section_inherit_mode_merge_exclude_unions_inherited_exclude
        files = SOURCE_FILES.merge("base.yml" => ALL_COPS_BASE_EXCLUDE, ".rubocop.yml" => ALL_COPS_MERGE_CONFIG,
                                   "app/clean.rb" => "# frozen_string_literal: true\n\nclass Clean\nend\n")
        write_project(files)
        assert_all_cops_clean(scan_json("."))
      end

      private

      def assert_all_cops_clean(json)
        assert_equal [0, 0, 1],
                     [@status.exitstatus, json.dig("summary", "offense_count"),
                      json.dig("summary", "inspected_file_count")]
      end

      def assert_both_suppressed(json, base_line:, project_line:)
        expected = [exclude_record("legacy/old.rb", "base.yml", base_line, "legacy reason"),
                    exclude_record("vendor_port/port.rb", ".rubocop.yml", project_line, "port reason")]
        assert_equal [0, 0, expected],
                     [@status.exitstatus, json.dig("summary", "offense_count"), json.fetch("suppressions")]
      end

      def assert_only_vendor_port_suppressed(json)
        expected = [exclude_record("vendor_port/port.rb", ".rubocop.yml", 10, "port reason")]
        assert_equal [1, 1], [@status.exitstatus, json.dig("summary", "offense_count")]
        assert_equal [["legacy/old.rb", LONG]], live_offenses(json)
        assert_equal expected, json.fetch("suppressions")
      end
    end
  end
end
