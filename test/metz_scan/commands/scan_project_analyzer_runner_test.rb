# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class ScanProjectAnalyzerRunnerTest < Minitest::Test
      def setup
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzer-runner-test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
      end

      def test_merges_project_findings_into_rubocop_json_shape
        write_repeated_branching_files
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge(parsed, [@tmpdir])

        assert_repeated_branching_offenses(parsed)
        assert_normalized_locations(parsed)
      end

      def test_matches_existing_file_entries_by_expanded_path
        parsed = parsed_with_relative_file
        Scan::ProjectAnalyzerRunner.merge_offenses(parsed, { expanded_fixture_path => [fake_offense] })

        assert_equal 1, parsed.fetch("files").size
        assert_equal [fake_offense], parsed.dig("files", 0, "offenses")
      end

      def test_merges_service_soup_findings
        write_service_soup_file
        parsed = { "files" => [], "summary" => { "offense_count" => 0 } }

        Scan::ProjectAnalyzerRunner.merge(parsed, [@tmpdir])
        assert_includes cop_names(parsed), "MetzProject/ServiceSoup"
      end

      def test_uses_rubocop_inspected_files_when_available
        write_repeated_branching_files
        parsed = { "files" => [{ "path" => branching_path(0), "offenses" => [] }] }

        Scan::ProjectAnalyzerRunner.merge(parsed, [@tmpdir])
        refute_includes cop_names(parsed), "MetzProject/RepeatedBranching"
      end

      private

      def assert_repeated_branching_offenses(parsed)
        offenses = offenses(parsed)
        assert_equal ["MetzProject/RepeatedBranching"], offenses.map { |o| o["cop_name"] }.uniq
        assert_equal offenses.size, parsed.dig("summary", "offense_count")
      end

      def assert_normalized_locations(parsed)
        assert offenses(parsed).all? { |o| o.dig("location", "last_column") }, "expected normalized locations"
      end

      def cop_names(parsed)
        offenses(parsed).map { |offense| offense.fetch("cop_name") }
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
        2.times do |index|
          File.write(branching_path(index), repeated_branching_source)
        end
      end

      def branching_path(index)
        File.join(@tmpdir, "branching_#{index}.rb")
      end

      def repeated_branching_source
        <<~RUBY
          # frozen_string_literal: true

          case order.status
          when "pending"
            nil
          when "paid", "cancelled"
            nil
          end
        RUBY
      end

      def write_service_soup_file
        File.write(File.join(@tmpdir, "service_soup.rb"), service_soup_source)
      end

      def service_soup_source
        <<~RUBY
          class OrdersController
            def create
              ValidateOrder.call(order)
              ReserveInventory.call(order)
              CapturePayment.new(order).call
            end
          end
        RUBY
      end
    end
  end
end
