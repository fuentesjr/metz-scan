# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"

module MetzScan
  module Commands
    module ScanProjectAnalyzerFixtures
      def violating_fixture
        <<~RUBY
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

      def setup_service_soup_source
        <<~RUBY
          # frozen_string_literal: true

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
      end
    end

    class ScanProjectAnalyzersTest < Minitest::Test
      include ScanProjectAnalyzerFixtures

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-project-analyzers-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_merges_project_analyzers_with_rubocop_json_output
        write_scan_fixture
        code = scan_project_analyzers

        assert_project_analyzer_output(code)
      end

      private

      def write_scan_fixture
        File.write(File.join(@tmpdir, "sample.rb"), violating_fixture)
        write_repeated_branching_files
      end

      def scan_project_analyzers
        run_scan([relative_tmpdir, "--project-analyzers", "--format", "json"])
      end

      def run_scan(argv)
        Scan.run(argv, stdout: @stdout, stderr: @stderr)
      end

      def relative_tmpdir
        @tmpdir.delete_prefix("#{Dir.pwd}/")
      end

      def write_repeated_branching_files
        2.times { |index| write_repeated_branching_file(index) }
      end

      def write_repeated_branching_file(index)
        File.write(File.join(@tmpdir, "branching_#{index}.rb"), repeated_branching_source)
      end

      def assert_mixed_offenses
        assert(rubocop_cop_names.any? { |name| name.start_with?("Metz/") })
        assert_includes rubocop_cop_names, "MetzProject/RepeatedBranching"
      end

      def assert_project_analyzer_output(code)
        refute_equal 0, code
        assert_mixed_offenses
        assert_unique_file_paths
        assert_summary_count_matches
        assert_project_analyzer_summary
      end

      def rubocop_cop_names
        json_offenses.map { |offense| offense.fetch("cop_name").to_s }
      end

      def assert_summary_count_matches
        assert_equal json_offenses.size, parsed_json.dig("summary", "offense_count")
      end

      def assert_project_analyzer_summary
        summary = parsed_json.dig("summary", "project_analyzers")

        assert_equal 1, summary.fetch("finding_count")
        assert_equal 2, summary.fetch("offense_count")
        assert_equal "validated", summary.dig("rules", 0, "status")
        assert_equal "medium", summary.dig("rules", 0, "confidence")
      end

      def assert_unique_file_paths
        paths = parsed_json.fetch("files").map { |file| File.expand_path(file.fetch("path")) }
        assert_equal paths.uniq, paths
      end

      def json_offenses
        parsed_json.fetch("files").flat_map { |file| file.fetch("offenses") }
      end

      def parsed_json
        @parsed_json ||= JSON.parse(@stdout.string)
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

    class ScanDefaultProjectAnalyzersTest < Minitest::Test
      include ScanProjectAnalyzerFixtures

      def setup
        @stdout = StringIO.new
        @stderr = StringIO.new
        configure_rubocop_cache_root
        FileUtils.mkdir_p(tmp_root)
        @tmpdir = Dir.mktmpdir("metz-scan-default-project-analyzers-test", tmp_root)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        FileUtils.rmdir(tmp_root) if File.directory?(tmp_root) && Dir.empty?(tmp_root)
        restore_rubocop_cache_root
      end

      def test_default_scan_includes_eligible_project_analyzer_findings
        write_repeated_branching_files
        code = scan_without_project_analyzers

        refute_equal 0, code
        assert_includes rubocop_cop_names, "MetzProject/RepeatedBranching"
      end

      def test_default_scan_ignores_project_config_excludes_for_default_output_analyzers
        write_project_config_excluding_repeated_branching_files
        write_repeated_branching_files
        code = scan_without_project_analyzers

        refute_equal 0, code
        assert_includes rubocop_cop_names, "MetzProject/RepeatedBranching"
      end

      def test_all_cops_respects_project_config_excludes_for_default_output_analyzers
        write_project_config_excluding_repeated_branching_files
        write_repeated_branching_files
        code = scan_all_cops_without_project_analyzers

        assert_equal 0, code
        refute_includes rubocop_cop_names, "MetzProject/RepeatedBranching"
      end

      def test_default_scan_excludes_low_confidence_project_analyzer_findings
        write_setup_service_soup_file
        code = scan_without_project_analyzers

        assert_equal 0, code
        refute_includes rubocop_cop_names, "MetzProject/ServiceSoup"
        refute parsed_json.fetch("summary").key?("project_analyzers")
      end

      private

      def scan_without_project_analyzers
        Scan.run([relative_tmpdir, "--format", "json"], stdout: @stdout, stderr: @stderr)
      end

      def scan_all_cops_without_project_analyzers
        Scan.run([relative_tmpdir, "--all-cops", "--format", "json"], stdout: @stdout, stderr: @stderr)
      end

      def relative_tmpdir
        @tmpdir.delete_prefix("#{Dir.pwd}/")
      end

      def write_repeated_branching_files
        2.times do |index|
          File.write(File.join(@tmpdir, "branching_#{index}.rb"), repeated_branching_source)
        end
      end

      def write_project_config_excluding_repeated_branching_files
        File.write(File.join(@tmpdir, ".rubocop.yml"), <<~YAML)
          AllCops:
            Exclude:
              - branching_*.rb
        YAML
      end

      def write_setup_service_soup_file
        File.write(File.join(@tmpdir, "setup_service_soup.rb"), setup_service_soup_source)
      end

      def rubocop_cop_names
        offenses = parsed_json.fetch("files").flat_map { |file| file.fetch("offenses") }

        offenses.map { |offense| offense.fetch("cop_name").to_s }
      end

      def parsed_json
        @parsed_json ||= JSON.parse(@stdout.string)
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
