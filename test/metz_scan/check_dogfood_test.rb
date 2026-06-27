# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  class CheckDogfoodTest < Minitest::Test
    REPO_ROOT = File.expand_path("../..", __dir__)
    Result = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
      def success? = status.success?
    end

    def test_no_offenses_passes
      result = run_check_dogfood(scan_json: report([]))

      assert result.success?
      assert_includes result.stdout, "accepted project-analyzer baseline: 0 findings"
    end

    def test_non_project_offenses_get_actionable_failure_output
      result = run_check_dogfood(scan_json: report([regular_offense]))

      refute result.success?
      assert_includes result.stderr, "non-project-analyzer offenses found"
      assert_includes result.stderr, "Fix these regular scan offenses before updating the dogfood baseline."
      assert_includes result.stderr, "Metz/MethodsTooLong"
    end

    def test_project_analyzer_drift_gets_actionable_failure_output
      result = run_check_dogfood(scan_json: report([changed_project_offense]))

      refute result.success?
      assert_project_drift_output(result.stderr)
    end

    private

    def assert_project_drift_output(stderr)
      assert_includes stderr, "project-analyzer findings differ from accepted baseline"
      assert_includes stderr, "Added project-analyzer finding"
      assert_includes stderr, "Next action: inspect `bin/check_dogfood` output"
    end

    def run_check_dogfood(scan_json:)
      Dir.mktmpdir("metz-scan-check-dogfood-test") do |dir|
        write_fake_bundle(dir)
        stdout, stderr, status = Open3.capture3(env_for(dir, scan_json), RbConfig.ruby, check_dogfood_path)
        return Result.new(stdout: stdout, stderr: stderr, status: status)
      end
    end

    def write_fake_bundle(dir)
      File.write(File.join(dir, "bundle"), fake_bundle_source)
      File.chmod(0o755, File.join(dir, "bundle"))
    end

    def fake_bundle_source
      <<~RUBY
        #!/usr/bin/env ruby
        if ARGV == ["exec", "ruby", "-e", "require 'rubydex'"]
          exit 0
        end

        print ENV.fetch("DOGFOOD_SCAN_JSON")
        exit ENV.fetch("DOGFOOD_SCAN_STATUS", "1").to_i
      RUBY
    end

    def env_for(dir, scan_json)
      { "PATH" => "#{dir}:#{ENV.fetch('PATH')}", "DOGFOOD_SCAN_JSON" => scan_json }
    end

    def check_dogfood_path
      File.join(REPO_ROOT, "bin/check_dogfood")
    end

    def report(offenses)
      { "files" => offenses.group_by { |offense| offense.fetch("path") }.map { |path, grouped| file(path, grouped) } }
        .to_json
    end

    def file(path, offenses)
      { "path" => path, "offenses" => offenses.map { |offense| offense.fetch("offense") } }
    end

    def regular_offense
      { "path" => "lib/example.rb",
        "offense" => { "cop_name" => "Metz/MethodsTooLong", "message" => "Method has too many lines." } }
    end

    def changed_project_offense
      { "path" => "lib/metz_scan/analyzers/inheritance_descendants.rb",
        "offense" => changed_project_offense_payload }
    end

    def changed_project_offense_payload
      { "cop_name" => "MetzProject/DeepInheritanceTree",
        "message" => "ApplicationController has 10 descendants; consider whether shared behavior is broad.",
        "project_analyzer" => changed_project_metadata }
    end

    def changed_project_metadata
      { "base_name" => "ApplicationController", "descendant_count" => 10 }
    end
  end
end
