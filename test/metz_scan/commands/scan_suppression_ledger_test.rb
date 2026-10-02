# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    # Spec tests for the suppression ledger (trk Next item "Suppression
    # ledger"; contract approved by the owner on 2026-10-01, see .trk/LOG.md).
    # Each test runs `metz-scan scan` as a subprocess inside a scratch project
    # so ledger paths are cwd-relative and stable.
    module SuppressionLedgerScan
      LONG = "Metz/MethodsTooLong"
      DEMETER = "Metz/DemeterTrainWreck"
      PARAMS = "Metz/MethodsTooManyParameters"
      MESSAGES = {
        LONG => "Metz/MethodsTooLong: Method has too many lines. [6/5]",
        DEMETER => "Metz/DemeterTrainWreck: Object-graph traversal of 5 exceeds Max (4). " \
                   "Consider delegating or wrapping intermediate calls.",
        PARAMS => "Metz/MethodsTooManyParameters: Avoid parameter lists longer than 4 parameters. [5/4]"
      }.freeze

      # An 8-line method (6 body lines) indented for a class body; trips
      # Metz/MethodsTooLong at column 3 of its `def` line.
      def self.long_method(name)
        ["def #{name}", "  a = 1", "  b = 2", "  c = 3", "  d = 4", "  e = 5", "  [a, b, c, d, e]", "end"]
          .map { |line| "  #{line}" }.join("\n")
      end

      def self.long_class(name)
        "class #{name}\n#{long_method('m')}\nend\n"
      end

      def setup
        @project = Dir.mktmpdir("metz-scan-suppression-ledger")
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

      def suppressions(*)
        ledger(scan_json(*))
      end

      def ledger(json)
        assert_includes json.keys, "suppressions", "a default-mode scan must emit the suppression ledger"
        json.fetch("suppressions")
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

      def finding(cop, path, line, column)
        { "cop_name" => cop, "path" => path, "line" => line, "column" => column, "message" => MESSAGES.fetch(cop) }
      end

      def inline_disable(directive_line, reason)
        { "suppressed_by" => "inline_disable", "directive" => { "line" => directive_line }, "config" => nil }
          .merge(reason_fields(reason))
      end

      def config_exclude(config_path, config_line, pattern, reason)
        config = { "path" => config_path, "line" => config_line, "pattern" => pattern }
        { "suppressed_by" => "config_exclude", "directive" => nil, "config" => config }.merge(reason_fields(reason))
      end

      def reason_fields(reason)
        { "reason" => reason, "reason_status" => reason ? "present" : "missing" }
      end
    end

    class ScanSuppressionLedgerInlineTest < Minitest::Test
      include SuppressionLedgerScan

      METHOD = SuppressionLedgerScan.method(:long_method)
      REASONS_FIXTURE = <<~RUBY.freeze
        class Inline
          # rubocop:disable Metz/MethodsTooLong -- mirrors vendor schema
        #{METHOD.call('with_reason')}
          # rubocop:enable Metz/MethodsTooLong

          # rubocop:disable Metz/MethodsTooLong
        #{METHOD.call('without_reason')}
          # rubocop:enable Metz/MethodsTooLong

          # rubocop:disable Metz/MethodsTooLong --
        #{METHOD.call('empty_reason')}
          # rubocop:enable Metz/MethodsTooLong
        end
      RUBY
      # The full record shape for an inline disable, spelled out once.
      WITH_REASON_RECORD = {
        "cop_name" => "Metz/MethodsTooLong", "path" => "app/inline.rb", "line" => 3, "column" => 3,
        "message" => "Metz/MethodsTooLong: Method has too many lines. [6/5]",
        "suppressed_by" => "inline_disable", "reason" => "mirrors vendor schema", "reason_status" => "present",
        "directive" => { "line" => 2 }, "config" => nil
      }.freeze
      FORMS_FIXTURE = <<~RUBY.freeze
        class Forms
          def single # rubocop:disable Metz/MethodsTooLong -- same line
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            [a, b, c, d, e]
          end

          # rubocop:disable-next Metz/MethodsTooLong -- next line
        #{METHOD.call('next_line')}

          def chain
            user
              .account
              .subscription
              .plan
              .name # rubocop:disable Metz/DemeterTrainWreck -- on last line
          end

          # rubocop:disable Metz/MethodsTooLong -- unclosed
        #{METHOD.call('unclosed')}
        end
      RUBY
      WIDE_FIXTURE = <<~RUBY.freeze
        class Wide
          # rubocop:todo Metz/MethodsTooLong -- todo reason
        #{METHOD.call('todo')}
          # rubocop:enable Metz/MethodsTooLong

          # rubocop:disable all -- all reason
        #{METHOD.call('everything')}
          # rubocop:enable all

          # rubocop:disable Metz -- department reason
        #{METHOD.call('department')}
          # rubocop:enable Metz
        end
      RUBY

      def test_inline_disables_record_the_directive_reason_or_its_absence
        write_file("app/inline.rb", REASONS_FIXTURE)
        assert_equal [WITH_REASON_RECORD,
                      finding(LONG, "app/inline.rb", 14, 3).merge(inline_disable(13, nil)),
                      finding(LONG, "app/inline.rb", 25, 3).merge(inline_disable(24, nil))], suppressions(".")
      end

      def test_each_directive_form_is_credited_with_its_own_line
        write_file("app/forms.rb", FORMS_FIXTURE)
        assert_equal [finding(LONG, "app/forms.rb", 2, 3).merge(inline_disable(2, "same line")),
                      finding(LONG, "app/forms.rb", 12, 3).merge(inline_disable(11, "next line")),
                      finding(DEMETER, "app/forms.rb", 22, 5).merge(inline_disable(26, "on last line")),
                      finding(LONG, "app/forms.rb", 30, 3).merge(inline_disable(29, "unclosed"))], suppressions(".")
      end

      def test_todo_all_and_department_directives_record_the_hidden_cop
        write_file("app/wide.rb", WIDE_FIXTURE)
        assert_equal [finding(LONG, "app/wide.rb", 3, 3).merge(inline_disable(2, "todo reason")),
                      finding(LONG, "app/wide.rb", 14, 3).merge(inline_disable(13, "all reason")),
                      finding(LONG, "app/wide.rb", 25, 3).merge(inline_disable(24, "department reason"))],
                     suppressions(".")
      end
    end

    class ScanSuppressionLedgerInlineCreditTest < Minitest::Test
      include SuppressionLedgerScan

      NESTED_FIXTURE = <<~RUBY.freeze
        # rubocop:disable Metz/MethodsTooLong -- outer reason
        class Nested
          # rubocop:disable Metz/MethodsTooLong
        #{SuppressionLedgerScan.long_method('m')}
          # rubocop:enable Metz/MethodsTooLong
        end
      RUBY
      TWO_COPS_FIXTURE = <<~RUBY
        class Report
          # rubocop:disable Metz/MethodsTooLong, Metz/DemeterTrainWreck -- legacy report
          def build
            a = user.account.subscription.plan.name
            b = 2
            c = 3
            d = 4
            e = 5
            [a, b, c, d, e]
          end
          # rubocop:enable Metz/MethodsTooLong, Metz/DemeterTrainWreck
        end
      RUBY
      # Opt-in cop before an `enable` (RuboCop marks it suppressed via a
      # synthetic config directive) and a disable that hides nothing.
      NOT_SUPPRESSIONS_FIXTURES = {
        "test/opt_test.rb" => <<~RUBY,
          class OptTest
            def test_before
              widget.send(:secret)
            end
            # rubocop:enable Metz/TestReachesPrivate
            def test_after
              widget.send(:secret)
            end
          end
        RUBY
        "app/short.rb" => <<~RUBY
          class Short
            # rubocop:disable Metz/MethodsTooLong -- nothing to hide
            def tiny
              1
            end
            # rubocop:enable Metz/MethodsTooLong
          end
        RUBY
      }.freeze

      def test_nested_ranges_credit_the_innermost_directive_not_an_outer_reason
        write_file("app/nested.rb", NESTED_FIXTURE)
        assert_equal [finding(LONG, "app/nested.rb", 4, 3).merge(inline_disable(3, nil))], suppressions(".")
      end

      def test_a_directive_naming_two_cops_records_each_hidden_finding
        write_file("app/report.rb", TWO_COPS_FIXTURE)
        assert_equal [finding(LONG, "app/report.rb", 3, 3).merge(inline_disable(2, "legacy report")),
                      finding(DEMETER, "app/report.rb", 4, 9).merge(inline_disable(2, "legacy report"))],
                     suppressions(".")
      end

      def test_opt_in_coverage_and_redundant_disables_are_not_recorded
        write_project(NOT_SUPPRESSIONS_FIXTURES)
        assert_equal [], suppressions(".")
      end
    end

    class ScanSuppressionLedgerExcludeTest < Minitest::Test
      include SuppressionLedgerScan

      LONG_CLASS = SuppressionLedgerScan.method(:long_class)
      ENTRY_COMMENTS_FIXTURES = {
        ".rubocop.yml" => <<~YAML,
          # Method length policy
          Metz/MethodsTooLong:
            Exclude:
              # generated by the vendor
              # schema importer
              - lib/generated/**/*
              - spec/**/* # specs build fixtures inline
              - script/**/*
        YAML
        "lib/generated/schema.rb" => LONG_CLASS.call("Schema"),
        "spec/b_spec.rb" => LONG_CLASS.call("BSpec"),
        "script/run.rb" => LONG_CLASS.call("Run")
      }.freeze
      KEY_COMMENTS_FIXTURES = {
        ".rubocop.yml" => <<~YAML,
          Metz/MethodsTooManyParameters:
            # adapters mirror third-party signatures
            Exclude:
              - app/adapters/**/*
          Metz/DemeterTrainWreck:
            Exclude: ["lib/reports/**/*"] # report DSL chains by design
        YAML
        "app/adapters/pay.rb" => "class Pay\n  def call(a, b, c, d, e)\n    [a, b, c, d, e]\n  end\nend\n",
        "lib/reports/sales.rb" => "class Sales\n  def total\n    user.account.subscription.plan.name\n  end\nend\n"
      }.freeze
      # The project entry overrides the base entry (no inherit_mode: merge),
      # so the applied entry is the project's, which has no comment.
      INHERIT_OVERRIDE_FIXTURES = {
        "base.yml" => "Metz/MethodsTooLong:\n  Exclude:\n    - spec/**/* # base reason\n",
        ".rubocop.yml" => "inherit_from: base.yml\nMetz/MethodsTooLong:\n  Exclude:\n    - spec/**/*\n",
        "spec/c_spec.rb" => LONG_CLASS.call("CSpec")
      }.freeze
      NESTED_CONFIG_FIXTURES = {
        "sub/.rubocop.yml" => "Metz/MethodsTooLong:\n  Exclude:\n    - legacy/**/* # frozen legacy port\n",
        "sub/legacy/old.rb" => LONG_CLASS.call("Old")
      }.freeze
      ERB_FIXTURES = {
        ".rubocop.yml" => <<~YAML,
          <% generated = "gen/**/*" %>
          Metz/MethodsTooLong:
            Exclude:
              - <%= generated %> # generated code
        YAML
        "gen/api.rb" => LONG_CLASS.call("Api")
      }.freeze
      ALIAS_FIXTURES = {
        ".rubocop.yml" => <<~YAML,
          Metz/MethodsTooManyParameters:
            Exclude: &shared
              - shared/**/* # shared code
          Metz/MethodsTooLong:
            Exclude: *shared
        YAML
        "shared/util.rb" => LONG_CLASS.call("Util")
      }.freeze

      def test_exclude_entries_take_their_reason_from_comments_on_or_above_the_entry
        write_project(ENTRY_COMMENTS_FIXTURES)
        assert_equal [comment_block_record, exclude_record("script/run.rb", 8, "script/**/*", nil),
                      exclude_record("spec/b_spec.rb", 7, "spec/**/*", "specs build fixtures inline")],
                     suppressions(".")
      end

      def test_exclude_key_comments_apply_when_the_entry_has_none_including_flow_form
        write_project(KEY_COMMENTS_FIXTURES)
        assert_equal [key_comment_record, flow_form_record], suppressions(".")
      end

      def test_attribution_goes_to_the_applied_entry_not_an_overridden_base_entry
        write_project(INHERIT_OVERRIDE_FIXTURES)
        assert_equal [exclude_record("spec/c_spec.rb", 4, "spec/**/*", nil)], suppressions(".")
      end

      def test_a_nested_config_exclude_is_attributed_to_the_nested_file
        write_project(NESTED_CONFIG_FIXTURES)
        expected = finding(LONG, "sub/legacy/old.rb", 2, 3)
                   .merge(config_exclude("sub/.rubocop.yml", 3, "legacy/**/*", "frozen legacy port"))
        assert_equal [expected], suppressions(".")
      end

      def test_erb_configs_read_reasons_from_rendered_text_without_a_line
        write_project(ERB_FIXTURES)
        assert_equal [exclude_record("gen/api.rb", nil, "gen/**/*", "generated code")], suppressions(".")
      end

      def test_an_entry_reached_through_a_yaml_alias_is_unchecked
        write_project(ALIAS_FIXTURES)
        expected = exclude_record("shared/util.rb", nil, "shared/**/*", nil).merge("reason_status" => "unchecked")
        assert_equal [expected], suppressions(".")
      end

      private

      def exclude_record(path, config_line, pattern, reason)
        finding(LONG, path, 2, 3).merge(config_exclude(".rubocop.yml", config_line, pattern, reason))
      end

      def comment_block_record
        exclude_record("lib/generated/schema.rb", 6, "lib/generated/**/*", "generated by the vendor schema importer")
      end

      def key_comment_record
        finding(PARAMS, "app/adapters/pay.rb", 2, 11)
          .merge(config_exclude(".rubocop.yml", 4, "app/adapters/**/*", "adapters mirror third-party signatures"))
      end

      def flow_form_record
        finding(DEMETER, "lib/reports/sales.rb", 3, 5)
          .merge(config_exclude(".rubocop.yml", 6, "lib/reports/**/*", "report DSL chains by design"))
      end
    end

    class ScanSuppressionLedgerMixedProjectTest < Minitest::Test
      include SuppressionLedgerScan

      MIXED_FIXTURES = {
        ".rubocop.yml" => "Metz/MethodsTooLong:\n  Exclude:\n    - spec/**/*\n",
        "app/live.rb" => SuppressionLedgerScan.long_class("Live"),
        "app/foo.rb" => <<~RUBY,
          class Foo
            # rubocop:disable Metz/MethodsTooLong -- mirrors vendor schema
          #{SuppressionLedgerScan.long_method('m')}
            # rubocop:enable Metz/MethodsTooLong
          end
        RUBY
        "spec/a_spec.rb" => SuppressionLedgerScan.long_class("ASpec")
      }.freeze
      # The full record shape for a per-cop Exclude, spelled out once.
      EXCLUDE_RECORD = {
        "cop_name" => "Metz/MethodsTooLong", "path" => "spec/a_spec.rb", "line" => 2, "column" => 3,
        "message" => "Metz/MethodsTooLong: Method has too many lines. [6/5]",
        "suppressed_by" => "config_exclude", "reason" => nil, "reason_status" => "missing",
        "directive" => nil, "config" => { "path" => ".rubocop.yml", "line" => 3, "pattern" => "spec/**/*" }
      }.freeze
      MIXED_TEXT = <<~TEXT
          app/live.rb:2:3 Metz/MethodsTooLong: Method has too many lines. [6/5]

        Suppressed findings: 2, 1 without a reason
          app/foo.rb:3:3 Metz/MethodsTooLong: Method has too many lines. [6/5]
            inline disable at line 2, reason: mirrors vendor schema
          spec/a_spec.rb:2:3 Metz/MethodsTooLong: Method has too many lines. [6/5]
            .rubocop.yml:3 Exclude "spec/**/*", no reason

        Summary
        -------
      TEXT
      INLINE_AND_EXCLUDE_FIXTURES = {
        ".rubocop.yml" => "Metz/MethodsTooLong:\n  Exclude:\n    - spec/**/* # specs build fixtures inline\n",
        "spec/d_spec.rb" => <<~RUBY
          class DSpec
            # rubocop:disable Metz/MethodsTooLong -- inline reason
          #{SuppressionLedgerScan.long_method('m')}
            # rubocop:enable Metz/MethodsTooLong
          end
        RUBY
      }.freeze

      def test_inline_and_exclude_records_sort_by_path_in_one_ledger
        write_project(MIXED_FIXTURES)
        inline = finding(LONG, "app/foo.rb", 3, 3).merge(inline_disable(2, "mirrors vendor schema"))
        assert_equal [inline, EXCLUDE_RECORD], suppressions(".")
      end

      def test_text_lists_the_ledger_between_offense_blocks_and_the_summary
        write_project(MIXED_FIXTURES)
        assert_includes scan(".").first, MIXED_TEXT
      end

      def test_files_passed_by_name_follow_the_same_ledger_rules
        write_project(MIXED_FIXTURES)
        assert_equal [EXCLUDE_RECORD], suppressions("spec/a_spec.rb")
        assert_equal(["inline_disable"], suppressions("app/foo.rb").map { |record| record.fetch("suppressed_by") })
      end

      def test_the_ledger_key_is_absent_under_all_cops
        write_project(MIXED_FIXTURES)
        suppressions(".")
        refute_includes scan_json(".", "--all-cops").keys, "suppressions"
      end

      def test_a_finding_hidden_by_both_an_inline_disable_and_an_exclude_is_one_config_record
        write_project(INLINE_AND_EXCLUDE_FIXTURES)
        expected = finding(LONG, "spec/d_spec.rb", 3, 3)
                   .merge(config_exclude(".rubocop.yml", 3, "spec/**/*", "specs build fixtures inline"))
        assert_equal [expected], suppressions(".")
      end
    end

    class ScanSuppressionLedgerOutputTest < Minitest::Test
      include SuppressionLedgerScan

      EXCLUDE_FIXTURES = ScanSuppressionLedgerExcludeTest
      ONLY_SUPPRESSED_FIXTURE = <<~RUBY.freeze
        class Only
          # rubocop:disable Metz/MethodsTooLong -- mirrors vendor schema
        #{SuppressionLedgerScan.long_method('m')}
          # rubocop:enable Metz/MethodsTooLong
        end
      RUBY
      ERB_TEXT = <<~TEXT
        Suppressed findings: 1, 0 without a reason
          gen/api.rb:2:3 Metz/MethodsTooLong: Method has too many lines. [6/5]
            .rubocop.yml Exclude "gen/**/*", reason: generated code

        Summary
        -------
      TEXT
      ALIAS_TEXT = <<~TEXT
        Suppressed findings: 1, 0 without a reason
          shared/util.rb:2:3 Metz/MethodsTooLong: Method has too many lines. [6/5]
            .rubocop.yml Exclude "shared/**/*", reason not checked

        Summary
        -------
      TEXT

      def test_suppressed_findings_are_listed_but_not_counted_and_do_not_fail_the_scan
        write_file("app/only.rb", ONLY_SUPPRESSED_FIXTURE)
        json = scan_json(".")
        summary = json.fetch("summary")
        assert_equal [0, 0, 1], [@status.exitstatus, summary.fetch("offense_count"), summary.fetch("clean_file_count")]
        assert_equal(["app/only.rb"], ledger(json).map { |record| record.fetch("path") })
      end

      def test_a_scan_with_nothing_suppressed_emits_an_empty_ledger_and_no_text_section
        write_file("app/live.rb", SuppressionLedgerScan.long_class("Live"))
        assert_equal [], suppressions(".")
        refute_includes scan(".").first, "Suppressed findings"
      end

      def test_text_omits_a_config_line_that_cannot_be_trusted
        write_project(EXCLUDE_FIXTURES::ERB_FIXTURES)
        assert_includes scan(".").first, ERB_TEXT
      end

      def test_text_says_reason_not_checked_and_does_not_count_it_as_missing
        write_project(EXCLUDE_FIXTURES::ALIAS_FIXTURES)
        assert_includes scan(".").first, ALIAS_TEXT
      end
    end
  end
end
