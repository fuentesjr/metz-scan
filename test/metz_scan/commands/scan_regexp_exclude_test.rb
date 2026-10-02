# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module Commands
    class ScanRegexpExcludeTest < Minitest::Test
      LONG_CLASS = <<~RUBY
        class Script
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
      CONFIG = "Metz/MethodsTooLong:\n  Exclude:\n    - !ruby/regexp /script\\//\n"

      def setup
        @project = Dir.mktmpdir("metz-scan-regexp-exclude")
      end

      def teardown
        FileUtils.remove_entry(@project) if @project
      end

      def test_regexp_exclude_is_reported_as_regexp_text_with_unchecked_reason
        write(".rubocop.yml", CONFIG)
        write("script/long.rb", LONG_CLASS)

        record = scan_json.fetch("suppressions").fetch(0)

        assert_equal "/script\\//", record.dig("config", "pattern")
        assert_equal "unchecked", record["reason_status"]
      end

      private

      def write(path, body)
        full_path = File.join(@project, path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, body)
      end

      def scan_json
        stdout, stderr, = Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, bin_path, "scan", ".",
                                         "--format", "json", chdir: @project)
        JSON.parse(stdout)
      rescue JSON::ParserError
        flunk "scan did not emit JSON: #{stderr}"
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def bin_path = File.join(repo_root, "bin/metz-scan")
      def repo_root = File.expand_path("../../..", __dir__)
    end
  end
end
