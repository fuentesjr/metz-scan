# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/report"
require "metz_scan/commands/scan"

module MetzScan
  module Commands
    module ScorecardReportHelpers
      def report(inspected_file_count, files)
        { "metadata" => {}, "files" => files,
          "summary" => { "offense_count" => files.sum { |file| file.fetch("offenses").size },
                         "target_file_count" => inspected_file_count,
                         "inspected_file_count" => inspected_file_count } }
      end

      def file(path, cop_names)
        { "path" => path, "offenses" => cop_names.each_with_index.map { |cop_name, index| offense(cop_name, index) } }
      end

      def offense(cop_name, index)
        { "cop_name" => cop_name, "message" => "#{cop_name} message", "severity" => "refactor",
          "location" => { "start_line" => index + 1, "start_column" => 1 } }
      end
    end

    class ReportScorecardTest < Minitest::Test
      include ScorecardReportHelpers

      SORTED_SCORECARD_ROWS = [
        ["app/models/order.rb", %w[Metz/MethodsTooLong Metz/MethodsTooLong MetzProject/RepeatedBranching]],
        ["app/controllers/users_controller.rb", %w[Metz/ControllersTooManyDirectCollaborators Metz/MethodsTooLong]],
        ["app/services/archive.rb", %w[MetzProject/ServiceSoup MetzProject/ServiceSoup]],
        ["app/models/account.rb", %w[Metz/MethodsTooLong]],
        ["app/jobs/sync_job.rb", %w[Layout/LineLength]],
        ["lib/z.rb", %w[MetzProject/RepeatedBranching]],
        ["lib/a.rb", %w[MetzProject/ServiceSoup]]
      ].freeze

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        @tmpdir = Dir.mktmpdir("metz-scan-report-scorecard-test")
        @json_path = File.join(@tmpdir, "report.json")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_text_format_appends_compliance_summary
        write_report(sample_report)

        refute_equal 0, run_report
        assert_equal fixture("report_text_summary.txt"), summary_block(@stdout.string)
      end

      def test_json_format_adds_summary_fields
        write_report(sample_report)
        run_report("--format", "json")

        summary = JSON.parse(@stdout.string).fetch("summary")
        assert_equal expected_summary_fields, summary.slice(*expected_summary_fields.keys)
      end

      def test_clean_json_with_no_offenses_exits_zero
        write_report(report(1, [file("x.rb", [])]))

        assert_equal 0, run_report
        assert_equal fixture("clean_text_summary.txt"), @stdout.string
      end

      def test_text_summary_reports_no_files_scanned_when_inspected_count_is_zero
        write_report(report(0, []))

        assert_equal 0, run_report
        assert_equal fixture("no_files_text_summary.txt"), @stdout.string
      end

      def test_text_summary_sorts_rollups_and_limits_worst_files
        write_report(report(8, SORTED_SCORECARD_ROWS.map { |path, cop_names| file(path, cop_names) }))

        refute_equal 0, run_report
        assert_equal fixture("sorted_text_summary.txt"), summary_block(@stdout.string)
      end

      private

      def sample_report
        report(1, [file("app/controllers/users_controller.rb",
                        %w[Metz/ControllersTooManyDirectCollaborators Metz/MethodsTooLong])])
      end

      def expected_summary_fields
        { "clean_file_count" => 0, "files_with_offenses" => 1,
          "offenses_by_cop" => { "Metz/ControllersTooManyDirectCollaborators" => 1, "Metz/MethodsTooLong" => 1 } }
      end

      def run_report(*extra_args)
        Report.run([@json_path, *extra_args], stdout: @stdout, stderr: @stderr)
      end

      def write_report(payload)
        File.write(@json_path, JSON.generate(payload))
      end

      def summary_block(output)
        output[output.rindex("Summary\n")..]
      end

      def fixture(name)
        File.read(File.expand_path("../../fixtures/scan_scorecard/#{name}", __dir__))
      end
    end

    class ScanScorecardTest < Minitest::Test
      VIOLATING_FIXTURE = <<~RUBY
        # frozen_string_literal: true
        class Sample
          def long_method
            a = 1
            b = 2
            c = 3
            d = 4
            e = 5
            f = 6
            g = 7
            h = 8
            [a, b, c, d, e, f, g, h]
          end
        end
      RUBY

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-scorecard-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_scan_text_appends_summary
        refute_equal 0, scan_violating

        assert_includes @stdout.string, "Summary\n-------\n"
        assert_includes @stdout.string, "Metz compliance: 0% (0/1 files clean)"
        assert_match(/\d+ offenses? across \d+ cops?/, @stdout.string)
      end

      def test_scan_json_adds_scorecard_fields
        refute_equal 0, scan_violating("--format", "json")

        summary = JSON.parse(@stdout.string).fetch("summary")
        assert_equal 0, summary.fetch("clean_file_count")
        assert_equal 1, summary.fetch("files_with_offenses")
        assert_equal expected_offenses_by_cop, summary.fetch("offenses_by_cop")
      end

      private

      def scan_violating(*extra_args)
        File.write(File.join(@tmpdir, "sample.rb"), VIOLATING_FIXTURE)
        Scan.run([@tmpdir, *extra_args], stdout: @stdout, stderr: @stderr)
      end

      def expected_offenses_by_cop
        offenses.each_with_object(Hash.new(0)) { |offense, counts| counts[offense.fetch("cop_name")] += 1 }
      end

      def offenses
        JSON.parse(@stdout.string).fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end

      def configure_rubocop_cache_root
        @original_rubocop_cache_root = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def restore_rubocop_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_rubocop_cache_root

        ENV["RUBOCOP_CACHE_ROOT"] = @original_rubocop_cache_root
      end
    end
  end
end
