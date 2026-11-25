# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    module ScanBaselineSupport
      METHOD_LENGTH = "Metz/MethodsTooLong"
      CLASS_LENGTH = "Metz/ClassesTooLong"
      DEMETER = "Metz/DemeterTrainWreck"
      SERVICE_SOUP = "MetzProject/ServiceSoup"
      BASELINE = %w[--baseline base.json].freeze
      CHAIN = "a.b.c.d.e\n"
      ADDED = "def added; 1; end\n"
      # Keep the workflow on one report location so the baseline contains one ServiceSoup offense.
      SERVICE_WORKFLOW = <<~SOURCE
        class OrdersController
          def create
            ValidateOrder.call(order); ReserveInventory.call(order); CapturePayment.new(order).call
          end
        end
      SOURCE

      def setup
        @project_dir = File.realpath(Dir.mktmpdir("metz-scan-baseline"))
        @original_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.join(@project_dir, "cache")
      end

      def teardown
        ENV["RUBOCOP_CACHE_ROOT"] = @original_cache_root
        FileUtils.remove_entry(@project_dir)
      end

      private

      def write_source(path, source)
        File.write(File.join(@project_dir, path), source)
      end

      def method_source(name, length)
        "def #{name}\n#{"  step\n" * length}end\n"
      end

      def class_source(length)
        "class Big\n#{"  step\n" * length}end\n"
      end

      def suppressed_method(reason)
        body = method_source("adapter", 7)
        "# rubocop:disable #{METHOD_LENGTH} -- #{reason}\n#{body}# rubocop:enable #{METHOD_LENGTH}\n"
      end

      def scan(*flags)
        @stdout = StringIO.new
        @stderr = StringIO.new
        Dir.chdir(@project_dir) { Scan.run([".", *flags], stdout: @stdout, stderr: @stderr) }
      end

      def save_baseline(*expected_cops, exit_code: 1)
        assert_equal exit_code, scan("--format", "json"), @stderr.string
        report = JSON.parse(@stdout.string)
        assert_equal expected_cops.sort, offenses(report).map { |o| o.fetch("cop_name") }.sort
        write_source("base.json", @stdout.string)
        report
      end

      def scan_delta_json(exit_code:)
        assert_equal exit_code, scan(*BASELINE, "--format", "json"), @stderr.string
        JSON.parse(@stdout.string)
      end

      def offenses(report)
        report.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def suppression_keys(report)
        report.fetch("suppressions").map do |item|
          path, *metadata = item.values_at("path", "cop_name", "suppressed_by", "reason")
          [File.expand_path(path, @project_dir), *metadata]
        end
      end

      def assert_baseline_counts(report, pre_existing:, new_count:, grown:)
        expected = { "pre_existing_offense_count" => pre_existing, "new_offense_count" => new_count,
                     "grown_offense_count" => grown }
        assert_equal expected, report.fetch("summary").fetch("baseline").slice(*expected.keys)
      end

      def assert_clean_delta(report, pre_existing)
        assert_empty offenses(report)
        assert_equal 0, report.fetch("summary").fetch("offense_count")
        assert_baseline_counts(report, pre_existing: pre_existing, new_count: 0, grown: 0)
      end

      def baseline_suppressions(*expected_cops)
        write_source("old.rb", suppressed_method("legacy compatibility"))
        report = save_baseline(*expected_cops, exit_code: expected_cops.empty? ? 0 : 1)
        expected = [File.join(@project_dir, "old.rb"), METHOD_LENGTH, "inline_disable", "legacy compatibility"]
        assert_equal [expected], suppression_keys(report)
      end

      def add_suppression
        write_source("old.rb", ADDED + suppressed_method("legacy compatibility"))
        write_source("new.rb", suppressed_method("new adapter"))
      end
    end

    class ScanBaselineValidationTest < Minitest::Test
      include ScanBaselineSupport

      def test_baseline_option_requires_a_file_argument
        write_source("clean.rb", ADDED)
        assert_invalid_baseline(["--baseline"], /missing argument|requires?.*(?:file|argument)/i)
      end

      def test_baseline_rejects_a_nonexistent_file
        write_source("clean.rb", ADDED)
        assert_invalid_baseline(BASELINE, /no such file|not found|does not exist|cannot (?:open|read)/i)
        assert_includes @stderr.string, "base.json"
      end

      def test_baseline_rejects_a_directory
        write_source("clean.rb", ADDED)
        Dir.mkdir(File.join(@project_dir, "base.json"))
        assert_invalid_baseline(BASELINE, /directory|not a (?:regular )?file/i)
      end

      def test_baseline_rejects_invalid_json
        write_source("clean.rb", ADDED)
        write_source("base.json", "{broken")
        assert_invalid_baseline(BASELINE, /invalid JSON|pars(?:e|ing)|malformed JSON/i)
      end

      {
        array: [],
        empty_object: {},
        non_array_files: { "files" => "bad" },
        missing_offenses: { "files" => [{ "path" => "a.rb" }] }
      }.each do |shape, report|
        define_method("test_baseline_rejects_#{shape}_as_a_scan_report") do
          write_source("clean.rb", ADDED)
          write_source("base.json", JSON.generate(report))
          assert_invalid_baseline(BASELINE, /scan report|report shape|\b(?:files|offenses)\b/i)
        end
      end

      private

      def assert_invalid_baseline(flags, reason)
        assert_equal 64, scan("--format", "json", *flags)
        assert_match(/baseline/i, @stderr.string)
        assert_match(reason, @stderr.string)
        assert_empty @stdout.string
        refute_match(/Traceback|\.rb:\d+:in /, @stderr.string)
      end
    end

    class ScanBaselineTest < Minitest::Test
      include ScanBaselineSupport

      def test_unchanged_findings_are_hidden_after_lines_shift
        assert_clean_shifted_method_delta(7)
      end

      def test_a_shrunk_method_is_hidden_even_when_it_still_exceeds_the_limit
        assert_clean_shifted_method_delta(6)
      end

      def test_new_method_in_a_file_with_a_baselined_method_is_reported
        write_source("sample.rb", method_source("legacy", 7))
        save_baseline(METHOD_LENGTH)
        write_source("sample.rb", method_source("legacy", 7) + method_source("brand_new", 6))

        report = assert_delta(METHOD_LENGTH, "new", %r{`brand_new`.*\[6/5\]})
        assert_baseline_counts(report, pre_existing: 1, new_count: 1, grown: 0)
      end

      def test_grown_method_is_reported
        write_source("sample.rb", method_source("legacy", 7))
        save_baseline(METHOD_LENGTH)
        write_source("sample.rb", ADDED + method_source("legacy", 9))

        report = assert_delta(METHOD_LENGTH, "grew", %r{`legacy`.*\[9/5\]})
        assert_baseline_counts(report, pre_existing: 0, new_count: 0, grown: 1)
      end

      def test_grown_class_is_reported
        baseline_class_length(105)
        report = assert_delta(CLASS_LENGTH, "grew", %r{`Big`.*\[105/100\]})
        assert_baseline_counts(report, pre_existing: 0, new_count: 0, grown: 1)
      end

      def test_unchanged_class_is_hidden_after_lines_shift
        baseline_class_length(102)
        assert_clean_delta(scan_delta_json(exit_code: 0), 1)
      end

      def test_shrunk_class_is_hidden_even_when_it_still_exceeds_the_limit
        baseline_class_length(101)
        assert_clean_delta(scan_delta_json(exit_code: 0), 1)
      end

      def test_grown_demeter_traversal_is_reported
        write_source("sample.rb", CHAIN)
        save_baseline(DEMETER)
        write_source("sample.rb", "a.b.c.d.e.f\n")

        report = assert_delta(DEMETER, "grew", /traversal of 6\b/i)
        assert_baseline_counts(report, pre_existing: 0, new_count: 0, grown: 1)
      end

      private

      def assert_delta(cop, status, message)
        report = scan_delta_json(exit_code: 1)
        assert_equal 1, report.fetch("summary").fetch("offense_count")
        assert_equal([[cop, status]], offenses(report).map { |o| o.values_at("cop_name", "baseline_status") })
        assert_match message, offenses(report).first.fetch("message")
        report
      end

      def assert_clean_shifted_method_delta(length)
        write_source("sample.rb", method_source("legacy", 7) + CHAIN + SERVICE_WORKFLOW)
        save_baseline(METHOD_LENGTH, DEMETER, SERVICE_SOUP)
        write_source("sample.rb", ADDED + method_source("legacy", length) + CHAIN + SERVICE_WORKFLOW)

        assert_clean_delta(scan_delta_json(exit_code: 0), 3)
      end

      def baseline_class_length(length)
        write_source("sample.rb", class_source(102))
        save_baseline(CLASS_LENGTH)
        write_source("sample.rb", ADDED + class_source(length))
      end
    end

    class ScanBaselineSuppressionTest < Minitest::Test
      include ScanBaselineSupport

      PARAMETER_COUNT = "Metz/MethodsTooManyParameters"
      LEGACY_REASON = "legacy compatibility"

      def test_new_suppression_with_same_reason_on_another_path_is_reported
        baseline_suppressions
        write_source("old.rb", ADDED + suppressed_method(LEGACY_REASON))
        write_source("new.rb", suppressed_method(LEGACY_REASON))

        assert_only_suppression("new.rb", METHOD_LENGTH, "inline_disable", LEGACY_REASON)
      end

      def test_changed_reason_is_reported_at_the_same_path
        baseline_suppressions
        write_source("old.rb", suppressed_method("new adapter"))

        assert_only_suppression("old.rb", METHOD_LENGTH, "inline_disable", "new adapter")
      end

      def test_changed_cop_is_reported_at_the_same_path_with_the_same_reason
        baseline_suppressions
        write_source("old.rb", <<~SOURCE)
          # rubocop:disable Metz/MethodsTooManyParameters -- legacy compatibility
          def adapter(a, b, c, d, e); end
          # rubocop:enable Metz/MethodsTooManyParameters
        SOURCE
        assert_only_suppression("old.rb", PARAMETER_COUNT, "inline_disable", LEGACY_REASON)
      end

      def test_changed_suppression_source_is_reported_with_other_fields_unchanged
        baseline_suppressions
        write_source("old.rb", method_source("adapter", 7))
        write_source(".rubocop.yml", "Metz/MethodsTooLong:\n  Exclude:\n    - old.rb # legacy compatibility\n")

        assert_only_suppression("old.rb", METHOD_LENGTH, "config_exclude", LEGACY_REASON)
      end

      private

      def assert_only_suppression(path, cop, suppressed_by, reason)
        report = scan_delta_json(exit_code: 0)
        assert_clean_delta(report, 0)
        expected = [File.join(@project_dir, path), cop, suppressed_by, reason]
        assert_equal [expected], suppression_keys(report)
      end
    end

    class ScanBaselineFormatTest < Minitest::Test
      include ScanBaselineSupport

      def test_text_report_shows_only_delta_findings_and_suppressions
        prepare_format_delta
        output = scan_delta_text("text")

        assert_text_findings(output)
        assert_text_suppressions(output)
        assert_text_summary(output)
      end

      def test_sarif_reports_only_new_and_grown_findings
        prepare_format_delta
        report = JSON.parse(scan_delta_text("sarif"))
        results = report.fetch("runs").flat_map { |run| run.fetch("results") }

        assert_delta_messages(results.map { |result| result.dig("message", "text") })
      end

      def test_github_annotations_report_only_new_and_grown_findings
        prepare_format_delta
        annotations = scan_delta_text("gh-annotations").lines.grep(/^::(?:warning|error|notice) /)

        assert_delta_messages(annotations)
      end

      private

      def scan_delta_text(format)
        assert_equal 1, scan(*BASELINE, "--format", format), @stderr.string
        @stdout.string
      end

      def prepare_format_delta
        write_source("sample.rb", method_source("hidden", 7) + method_source("growing", 7))
        baseline_suppressions(METHOD_LENGTH, METHOD_LENGTH)
        updated = method_source("hidden", 7) + method_source("growing", 9) + method_source("brand_new", 6)
        write_source("sample.rb", updated)
        add_suppression
      end

      def assert_delta_messages(messages)
        assert_equal 2, messages.size
        assert_match(%r{`brand_new`.*\[6/5\]}, messages.join("\n"))
        assert_match(%r{`growing`.*\[9/5\]}, messages.join("\n"))
      end

      def assert_text_findings(output)
        assert_delta_messages(output.lines.grep(/Method `(?:hidden|brand_new|growing)`/))
        refute_includes output, "`hidden`"
      end

      def assert_text_suppressions(output)
        assert_includes output, "new adapter"
        refute_includes output, "legacy compatibility"
        assert_match(/^Suppressed findings: 1\b/, output)
      end

      def assert_text_summary(output)
        assert_match(/^Summary\b.*\b2 offenses\b/m, output)
        baseline = output[/^\s*Baseline:.*$/i].to_s
        assert_match(/\b1 new\b|\bnew\s*[:=]\s*1\b/i, baseline)
        assert_match(/\b1 grew\b|\bgrew\s*[:=]\s*1\b/i, baseline)
        assert_match(/\b1 pre-existing(?: hidden)?\b|\bpre-existing(?: hidden)?\s*[:=]\s*1\b/i, baseline)
      end
    end
  end
end
