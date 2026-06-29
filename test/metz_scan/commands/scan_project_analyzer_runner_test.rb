# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    PROJECT_ANALYZER_BRANCHING_SOURCE = "case order.status\nwhen \"pending\"\n  nil\n" \
                                        "when \"paid\", \"cancelled\"\n  nil\nend\n"
    PROJECT_ANALYZER_SERVICE_SOUP_SOURCE = <<~RUBY
      class OrdersController
        def create
          ValidateOrder.call(order)
          ReserveInventory.call(order)
          CapturePayment.new(order).call
        end
      end
    RUBY
    PROJECT_ANALYZER_SETUP_SERVICE_SOUP_SOURCE = <<~RUBY
      module Spree
        module Seeds
          class All
            def call
              Countries.call
              States.call
              Zones.call
            end
          end
        end
      end
    RUBY

    class ScanProjectAnalyzerRunnerTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzer-runner-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_merges_project_findings_into_rubocop_json_shape
        write_repeated_branching_files
        parsed = merge_project_analyzers

        assert_repeated_branching_offenses(parsed)
        assert_normalized_locations(parsed)
        assert_summary_counts_match_merged_files(parsed)
      end

      def test_active_project_analyzers_are_the_documented_opt_in_set
        assert_equal expected_active_analyzers.map(&:name).sort, Scan::ProjectAnalyzerRunner::ANALYZERS.map(&:name).sort
      end

      def test_matches_existing_file_entries_by_expanded_path
        parsed = parsed_with_relative_file
        Scan::ProjectAnalyzerRunner.merge_offenses(parsed, { expanded_fixture_path => [fake_offense] })

        assert_equal 1, parsed.fetch("files").size
        assert_equal [fake_offense], parsed.dig("files", 0, "offenses")
      end

      def test_merges_service_soup_findings
        write_service_soup_file
        parsed = merge_project_analyzers

        assert_includes cop_names(parsed), "MetzProject/ServiceSoup"
        assert_service_soup_metadata(parsed)
        assert_summary_counts_match_merged_files(parsed)
      end

      def test_uses_rubocop_target_files_when_json_files_are_partial
        write_repeated_branching_files
        parsed = { "files" => [{ "path" => branching_path(0), "offenses" => [] }] }

        Scan::ProjectAnalyzerRunner.merge!(parsed, [@tmpdir])
        assert_includes cop_names(parsed), "MetzProject/RepeatedBranching"
      end

      def test_rubocop_target_files_exclude_setup_service_soup_fixture
        targets = Scan::ProjectAnalyzerRunner.rubocop_target_files(["."])

        refute(targets.any? { |path| path.include?("test/fixtures/service_soup_setup_app/") })
      end

      private

      def expected_active_analyzers
        [Analyzers::RepeatedBranching, Analyzers::ServiceSoup,
         Analyzers::InheritanceDescendants, Analyzers::PackageDependencyPressure,
         Analyzers::NamespaceLeakPressure]
      end

      def merge_project_analyzers
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [@tmpdir])
        end
      end

      def assert_repeated_branching_offenses(parsed)
        offenses = offenses(parsed)
        assert_equal ["MetzProject/RepeatedBranching"], offenses.map { |o| o["cop_name"] }.uniq
        assert_equal offenses.size, parsed.dig("summary", "offense_count")
      end

      def assert_normalized_locations(parsed)
        assert offenses(parsed).all? { |o| o.dig("location", "last_column") }, "expected normalized locations"
      end

      def assert_summary_counts_match_merged_files(parsed)
        assert_equal parsed.fetch("files").size, parsed.dig("summary", "target_file_count")
        assert_equal parsed.fetch("files").size, parsed.dig("summary", "inspected_file_count")
      end

      def cop_names(parsed)
        offenses(parsed).map { |offense| offense.fetch("cop_name") }
      end

      def service_soup_offense(parsed)
        offenses(parsed).find { |offense| offense.fetch("cop_name") == "MetzProject/ServiceSoup" }
      end

      def assert_service_soup_metadata(parsed)
        offense = service_soup_offense(parsed)
        refute_empty offense.fetch("suggested_next_moves")
        assert_equal "OrdersController#create", offense.dig("project_analyzer", "workflow", "context")
      end

      def offenses(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }
      end

      def parsed_with_relative_file
        { "files" => [{ "path" => fixture_path, "offenses" => [] }] }
      end

      def expanded_fixture_path
        File.expand_path(fixture_path)
      end

      def fixture_path
        "scan-test-tmp/project_analyzer_runner.rb"
      end

      def fake_offense
        { "cop_name" => "MetzProject/Fake" }
      end

      def write_repeated_branching_files
        2.times { |index| File.write(branching_path(index), PROJECT_ANALYZER_BRANCHING_SOURCE) }
      end

      def branching_path(index)
        File.join(@tmpdir, "branching_#{index}.rb")
      end

      def write_service_soup_file
        File.write(File.join(@tmpdir, "service_soup.rb"), PROJECT_ANALYZER_SERVICE_SOUP_SOURCE)
      end
    end

    class ScanProjectAnalyzerRunnerDefaultOutputTest < Minitest::Test
      class ValidatedOptInOnlyAnalyzer
        PROJECT_ANALYZER_STATUS = "validated"

        def initialize(paths: nil, index: nil); end

        def call = []
      end

      def setup
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzer-default-output-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_default_output_keeps_only_eligible_project_findings
        write_repeated_branching_files
        write_setup_service_soup_file
        parsed = merge_default_project_analyzers

        assert_equal ["MetzProject/RepeatedBranching"], cop_names(parsed).uniq
        assert_equal ["MetzProject/RepeatedBranching"], summary_cop_names(parsed)
      end

      def test_validated_status_alone_does_not_make_analyzer_default_eligible
        refute Scan::ProjectAnalyzerRunner.default_output_analyzer?(ValidatedOptInOnlyAnalyzer)
      end

      def test_default_output_analyzers_are_explicitly_eligible
        assert Scan::ProjectAnalyzerRunner.default_output_analyzer?(Analyzers::RepeatedBranching)
        assert Scan::ProjectAnalyzerRunner.default_output_analyzer?(Analyzers::ServiceSoup)
        refute Scan::ProjectAnalyzerRunner.default_output_analyzer?(Analyzers::InheritanceDescendants)
      end

      private

      def merge_default_project_analyzers
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [@tmpdir], default_output: true)
        end
      end

      def cop_names(parsed)
        parsed["files"].flat_map { |file| file["offenses"] }.map { |offense| offense.fetch("cop_name") }
      end

      def summary_cop_names(parsed)
        parsed.dig("summary", "project_analyzers", "rules").map { |rule| rule.fetch("cop_name") }
      end

      def write_repeated_branching_files
        2.times { |index| File.write(branching_path(index), PROJECT_ANALYZER_BRANCHING_SOURCE) }
      end

      def write_setup_service_soup_file
        File.write(File.join(@tmpdir, "setup_service_soup.rb"), PROJECT_ANALYZER_SETUP_SERVICE_SOUP_SOURCE)
      end

      def branching_path(index)
        File.join(@tmpdir, "branching_#{index}.rb")
      end
    end

    class ScanProjectAnalyzerRunnerDisplayPathTest < Minitest::Test
      def teardown
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
      end

      def test_appends_project_local_files_with_relative_paths
        with_project_local_branching_files do |relative_path|
          parsed = merge_project_analyzers(relative_path)
          assert_relative_project_path(parsed, relative_path)
        end
      end

      private

      def with_project_local_branching_files
        FileUtils.mkdir_p(tmp_root)
        Dir.mktmpdir("metz-scan-project-analyzer-runner-test", tmp_root) { |dir| yield prepare_branching_dir(dir) }
      end

      def prepare_branching_dir(dir)
        write_repeated_branching_files(dir)
        dir.delete_prefix("#{Dir.pwd}/")
      end

      def write_repeated_branching_files(dir)
        2.times { |index| File.write(File.join(dir, "branching_#{index}.rb"), PROJECT_ANALYZER_BRANCHING_SOURCE) }
      end

      def merge_project_analyzers(path)
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [path])
        end
      end

      def assert_relative_project_path(parsed, relative_path)
        assert_includes file_paths(parsed), File.join(relative_path, "branching_0.rb")
        refute(file_paths(parsed).any? { |path| path.start_with?(Dir.pwd) })
      end

      def file_paths(parsed)
        parsed.fetch("files").map { |file| file.fetch("path") }
      end

      def tmp_root
        File.expand_path("../../../scan-test-tmp", __dir__)
      end
    end

    class ScanProjectAnalyzerRunnerExclusionTest < Minitest::Test
      def test_project_analyzers_honor_rubocop_excluded_directories
        parsed = merge_project_analyzers("test/fixtures/service_soup_app")

        assert_empty parsed.fetch("files")
        refute parsed.fetch("summary").key?("project_analyzers")
      end

      private

      def merge_project_analyzers(path)
        { "files" => [], "summary" => { "offense_count" => 0 } }.tap do |parsed|
          Scan::ProjectAnalyzerRunner.merge!(parsed, [path])
        end
      end
    end
  end
end
