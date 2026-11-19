# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "socket"
require "stringio"
require "tmpdir"

require "metz_scan/commands/scan"
require "metz_scan/commands/scan/project_analyzer_runner"

module MetzScan
  module Commands
    class LoopbackConfigServer
      def initialize(routes)
        @routes = routes
        @server = TCPServer.new("127.0.0.1", 0)
        @running = true
      end

      def port
        @server.addr[1]
      end

      def start
        @thread = Thread.new { accept_loop }
        self
      end

      def stop
        @running = false
        @server.close unless @server.closed?
        @thread&.join(2)
      end

      private

      def accept_loop
        serve(@server.accept) while @running
      rescue IOError, Errno::EBADF
        nil
      end

      def serve(client)
        method, path = read_request(client)
        respond(client, path, method == "HEAD")
      ensure
        client&.close
      end

      def read_request(client)
        line = client.gets.to_s
        drain_headers(client)
        line.split(" ", 3).first(2)
      end

      def drain_headers(client)
        loop do
          line = client.gets
          break if line.nil? || line == "\r\n"
        end
      end

      def respond(client, path, head_only)
        body = @routes[path]
        return client.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") unless body

        client.write(ok_headers(body))
        client.write(body) unless head_only
      end

      def ok_headers(body)
        "HTTP/1.1 200 OK\r\nContent-Type: text/yaml\r\n" \
          "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n"
      end
    end

    module AllCopsAnalyzerScopeFixtures
      SERVICE_SOUP_SOURCE = <<~RUBY
        # frozen_string_literal: true

        class OrdersController
          def create(order)
            ValidateOrder.call(order)
            ReserveInventory.call(order)
            CapturePayment.call(order)
          end
        end
      RUBY
      CLEAN_RUBY_SOURCE = "# frozen_string_literal: true\n\nCLEAN = 1\n"
      REMOTE_ALL_COPS_EXCLUDE = <<~YAML
        AllCops:
          NewCops: disable
          Exclude:
            - "legacy/**/*"
      YAML
      REMOTE_DISABLED_ANALYZER = <<~YAML
        AllCops:
          NewCops: disable
          SuggestExtensions: false
        Style/Documentation:
          Enabled: false
        MetzProject/ServiceSoup:
          Enabled: false
      YAML
      REMOTE_EXCLUDED_ANALYZER = <<~YAML
        AllCops:
          NewCops: disable
          SuggestExtensions: false
        Style/Documentation:
          Enabled: false
        MetzProject/ServiceSoup:
          Exclude:
            - "app/workflows/**/*"
      YAML
    end

    class ScanAllCopsRemoteConfigScopeTest < Minitest::Test
      include AllCopsAnalyzerScopeFixtures

      def setup
        @project = File.realpath(Dir.mktmpdir("metz-scan-remote-scope"))
        @server = LoopbackConfigServer.new(routes).start
      end

      def teardown
        @server&.stop
        FileUtils.remove_entry(@project) if @project
      end

      def test_all_cops_honors_all_cops_exclude_from_remote_inherit_from
        setup_remote_all_cops_exclude_project
        report = assert_clean_all_cops_scan
        refute_includes report_paths(report), "legacy/orders_controller.rb"
      end

      def test_all_cops_honors_analyzer_enabled_false_from_remote_inherit_from
        setup_remote_workflow_project("/remote_disabled.yml")
        assert_clean_all_cops_scan
      end

      def test_all_cops_honors_analyzer_exclude_from_remote_inherit_from
        setup_remote_workflow_project("/remote_exclude.yml")
        assert_clean_all_cops_scan
      end

      private

      def routes
        { "/remote.yml" => REMOTE_ALL_COPS_EXCLUDE,
          "/remote_disabled.yml" => REMOTE_DISABLED_ANALYZER,
          "/remote_exclude.yml" => REMOTE_EXCLUDED_ANALYZER }
      end

      def setup_remote_all_cops_exclude_project
        write_project_file(".rubocop.yml", "inherit_from: #{remote_url('/remote.yml')}\n")
        write_project_file("legacy/orders_controller.rb", SERVICE_SOUP_SOURCE)
        write_project_file("app/clean.rb", "# frozen_string_literal: true\n")
      end

      def setup_remote_workflow_project(route)
        write_project_file(".rubocop.yml", "inherit_from: #{remote_url(route)}\n")
        write_project_file("app/workflows/orders_controller.rb", SERVICE_SOUP_SOURCE)
      end

      def remote_url(path)
        "http://127.0.0.1:#{@server.port}#{path}"
      end

      def write_project_file(relative_path, content)
        full_path = File.join(@project, relative_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
      end

      def assert_clean_all_cops_scan
        stdout, stderr, status = run_all_cops_json_scan
        assert_equal 0, status.exitstatus, "stdout:\n#{stdout}\nstderr:\n#{stderr}"
        assert_clean_report(JSON.parse(stdout))
      end

      def assert_clean_report(report)
        assert_equal 0, report.dig("summary", "offense_count")
        assert_operator report.dig("summary", "inspected_file_count"), :>=, 1
        refute_includes report_offense_cops(report), "MetzProject/ServiceSoup"
        report
      end

      def run_all_cops_json_scan
        Open3.capture3(subprocess_env, "bundle", "exec", RbConfig.ruby, bin_path,
                       "scan", ".", "--all-cops", "--format", "json", chdir: @project)
      end

      def subprocess_env
        { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"),
          "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache"),
          "RUBOCOP_TARGET_RUBY_VERSION" => nil }
      end

      def report_paths(report)
        report.fetch("files").map { |file| file.fetch("path") }
      end

      def report_offense_cops(report)
        report.fetch("files").flat_map { |file| file.fetch("offenses") }.map { |offense| offense.fetch("cop_name") }
      end

      def bin_path = File.join(repo_root, "bin/metz-scan")
      def repo_root = File.expand_path("../../..", __dir__)
    end

    class ScanTargetDiscoveryAndRunnerSignatureTest < Minitest::Test
      def setup
        @tmpdir = File.realpath(Dir.mktmpdir("metz-scan-discovery-count"))
        @original_cache = ENV.fetch("RUBOCOP_CACHE_ROOT", nil)
        ENV["RUBOCOP_CACHE_ROOT"] = File.expand_path("../../../tmp/rubocop_cache", __dir__)
      end

      def teardown
        FileUtils.remove_entry(@tmpdir) if @tmpdir
        restore_cache_root
      end

      def test_default_scan_invokes_target_file_discovery_at_most_once
        File.write(File.join(@tmpdir, "clean.rb"), AllCopsAnalyzerScopeFixtures::CLEAN_RUBY_SOURCE)
        calls = count_discovery_calls { assert_clean_in_process_scan }
        assert_operator calls, :<=, 1, "expected at most 1 TargetFileDiscovery.for_project_config call, got #{calls}"
      end

      def test_project_analyzer_runner_omits_dead_force_default_config_parameter
        params = Scan::ProjectAnalyzerRunner.method(:project_findings_for).parameters.map(&:last)
        refute_includes params, :force_default_config
      end

      private

      def assert_clean_in_process_scan
        out = StringIO.new
        err = StringIO.new
        code = Scan.run([@tmpdir, "--format", "json"], stdout: out, stderr: err)
        assert_equal 0, code, err.string
      end

      def count_discovery_calls(&)
        calls = 0
        with_counted_discovery(-> { calls += 1 }, &)
        calls
      end

      def with_counted_discovery(counter)
        original = Scan::TargetFileDiscovery.method(:for_project_config)
        override_discovery(original, counter)
        yield
      ensure
        restore_discovery(original)
      end

      def override_discovery(original, counter)
        Scan::TargetFileDiscovery.define_singleton_method(:for_project_config) do |paths|
          counter.call
          original.call(paths)
        end
      end

      def restore_discovery(original)
        Scan::TargetFileDiscovery.define_singleton_method(:for_project_config, original) if original
      end

      def restore_cache_root
        return ENV.delete("RUBOCOP_CACHE_ROOT") unless @original_cache

        ENV["RUBOCOP_CACHE_ROOT"] = @original_cache
      end
    end
  end
end
