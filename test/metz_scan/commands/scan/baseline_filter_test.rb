# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "rubocop-metz"
require "metz_scan/commands/scan"

module MetzScan
  module Commands
    class BaselineFilterRegressionTest < Minitest::Test
      FakeFinding = Struct.new(:rule_id, :message, :why_it_matters, :suggested_next_moves, :project_analyzer_status,
                               :confidence, :triage_severity, :triage_summary, :report_occurrences, keyword_init: true)
      FakeOccurrence = Struct.new(:path, :report_line, :line_source, :context, keyword_init: true)

      def test_preserves_digits_in_identifier_names_when_pairing_offenses
        base = report_with("a.rb", "Metz/MethodsTooLong",
                           "Method `work coordinates 2 distinct services` has too many lines. [7/5]")
        curr = report_with("a.rb", "Metz/MethodsTooLong",
                           "Method `work coordinates 3 distinct services` has too many lines. [7/5]")

        Scan::BaselineFilter.apply!(curr, base)

        assert_equal(["new"], curr.dig("files", 0, "offenses").map { |o| o["baseline_status"] })
        assert_equal 0, curr.dig("summary", "baseline", "pre_existing_offense_count")
      end

      def test_extracts_trailing_ratio_even_when_method_name_contains_brackets
        base = report_with("a.rb", "Metz/MethodsTooLong", "Method `op[2/1]` has too many lines. [7/5]")
        curr = report_with("a.rb", "Metz/MethodsTooLong", "Method `op[2/1]` has too many lines. [9/5]")

        Scan::BaselineFilter.apply!(curr, base)

        assert_equal(["grew"], curr.dig("files", 0, "offenses").map { |o| o["baseline_status"] })
      end

      def test_detects_growth_when_operation_public_method_list_expands
        cop = "Metz/OperationsTooManyPublicMethods"
        base_msg = "Operation `Checkout` defines 2 public methods (:call, :refund); " \
                   "keep a single public entry (max 1, excluding :initialize)."
        curr_msg = "Operation `Checkout` defines 3 public methods (:call, :refund, :preview); " \
                   "keep a single public entry (max 1, excluding :initialize)."
        curr = report_with("app/services/checkout.rb", cop, curr_msg)

        Scan::BaselineFilter.apply!(curr, report_with("app/services/checkout.rb", cop, base_msg))

        assert_equal(["grew"], curr.dig("files", 0, "offenses").map { |o| o["baseline_status"] })
      end

      def test_loader_rejects_malformed_offense_location_and_suppression_path
        Dir.mktmpdir do |dir|
          bad_offense = { "cop_name" => "X", "message" => "m", "location" => "bad" }
          bad_loc = write_json(dir, "bad_loc.json", "files" => [{ "path" => "a.rb", "offenses" => [bad_offense] }])
          assert_raises(Scan::BaselineLoader::Error) { Scan::BaselineLoader.load(bad_loc) }

          bad_sup = write_json(dir, "bad_sup.json", "files" => [], "suppressions" => [{ "path" => 123 }])
          assert_raises(Scan::BaselineLoader::Error) { Scan::BaselineLoader.load(bad_sup) }

          nul_path = write_json(dir, "nul.json", "files" => [{ "path" => "a\u0000b.rb", "offenses" => [] }])
          assert_raises(Scan::BaselineLoader::Error) { Scan::BaselineLoader.load(nul_path) }
        end
      end

      def test_scorecard_preserves_pre_baseline_compliance_when_findings_are_hidden
        base = report_with("a.rb", "Metz/MethodsTooLong", "Method `legacy` has too many lines. [7/5]")
        curr = report_with("a.rb", "Metz/MethodsTooLong", "Method `legacy` has too many lines. [7/5]")

        Scan::ComplianceScorecard.record_file_counts!(curr)
        Scan::BaselineFilter.apply!(curr, base)
        Scan::ComplianceScorecard.add_to_summary!(curr)

        assert_equal 0, curr.dig("summary", "clean_file_count")
        assert_equal 1, curr.dig("summary", "files_with_offenses")
        assert_includes Scan::ComplianceScorecard.new(curr).lines, "Metz compliance: 0% (0/1 files clean)"
      end

      def test_recomputes_project_analyzer_summary_from_surviving_entries_only
        high = fake_service_finding("medium", "design pressure", "A#call coordinates 3 distinct services", ["a.rb", 2])
        low = fake_service_finding("low", "setup orchestration", "B#call coordinates 3 distinct services",
                                   ["b.rb", 4], ["b.rb", 5])
        set = Scan::ProjectAnalyzerOffenses.build([high, low])
        curr = analyzer_report_from(set)
        base = { "files" => [{ "path" => "a.rb", "offenses" => [Marshal.load(Marshal.dump(set.offenses.first))] }] }

        Scan::BaselineFilter.apply!(curr, base, analyzer_entries: set.pairs)

        pa = curr.dig("summary", "project_analyzers")
        assert_equal [1, 2], [pa.fetch("finding_count"), pa.fetch("offense_count")]
        assert_equal ["low", "setup orchestration"], pa.fetch("rules").first.values_at("confidence", "triage_severity")
      end

      def test_cop_constructor_edge_cases_handle_cbase_and_anonymous_class_new
        cfg = RuboCop::Config.new("Metz/ClassesTooLong" => { "Max" => 2, "CountComments" => false, "CountAsOne" => [] })
        cls = RuboCop::Cop::Metz::ClassesTooLong
        assert_equal ["Class has too many lines. [3/2]"],
                     inspect_source(cls.new(cfg), "Class.new do\n  a = 1\n  b = 2\n  c = 3\nend\n").map(&:message)
        assert_equal ["Class `::Big` has too many lines. [3/2]"],
                     inspect_source(cls.new(cfg), "::Big = Class.new do\n  a = 1\n  b = 2\n  c = 3\nend\n")
                       .map(&:message)

        op_cfg = RuboCop::Config.new("Metz/OperationsTooManyPublicMethods" => { "MaxPublicMethods" => 1 })
        op_src = "::Big = Class.new do\n  def call; end\n  def refund; end\nend\n"
        op = inspect_source(RuboCop::Cop::Metz::OperationsTooManyPublicMethods.new(op_cfg), op_src, "app/services/b.rb")
        assert_includes op.first.message, "Operation `::Big` defines 2 public methods"
      end

      private

      def write_json(dir, name, payload)
        File.join(dir, name).tap { |path| File.write(path, JSON.generate(payload)) }
      end

      def analyzer_report_from(set)
        { "files" => set.by_path.map { |path, offenses| { "path" => path, "offenses" => offenses.dup } },
          "summary" => { "project_analyzers" => Scan::ProjectAnalyzerMetadata.summary(set.findings, set.offenses) } }
      end

      def report_with(path, cop_name, message)
        offense = { "cop_name" => cop_name, "message" => message,
                    "location" => { "start_line" => 1, "start_column" => 1 } }
        { "files" => [{ "path" => path, "offenses" => [offense] }],
          "summary" => { "inspected_file_count" => 1, "offense_count" => 1 } }
      end

      def fake_service_finding(confidence, severity, message, *locs)
        occurrences = locs.map do |path, line|
          FakeOccurrence.new(path: path, report_line: line, line_source: "source", context: nil)
        end
        FakeFinding.new(rule_id: "MetzProject/ServiceSoup", message: message, why_it_matters: "why",
                        suggested_next_moves: ["move"], project_analyzer_status: "validated", confidence: confidence,
                        triage_severity: severity, triage_summary: "summary", report_occurrences: occurrences)
      end

      def inspect_source(cop, source, path = "sample.rb")
        processed = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
        RuboCop::Cop::Commissioner.new([cop], []).investigate(processed).offenses
      end
    end
  end
end
