# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

module MetzScan
  module AnalyzerSuppressionFixtures
    SERVICE = "MetzProject/ServiceSoup"
    BRANCH = "MetzProject/RepeatedBranching"
    RULES = %w[
      MetzProject/RepeatedBranching MetzProject/ServiceSoup MetzProject/DeepInheritanceTree
      MetzProject/PackageDependencyPressure MetzProject/NamespaceLeakPressure MetzProject/ImplicitContextPressure
      MetzProject/RepeatedQueryCriteria MetzProject/SubclassOverridePressure MetzProject/TestCallsPrivateMethod
    ].freeze
    WORKFLOW = "app/workflows/orders.rb"
    SERVICE_MESSAGE = "OrdersController#create coordinates 3 distinct services; " \
                      "consider a workflow object that owns the process."
    BRANCH_MESSAGE = "order.status (state branch subject) branches in 2 files; consider consolidating the decision."
    CONFIG = <<~YAML
      plugins: [rubocop-metz]
      AllCops:
        NewCops: disable
        DisabledByDefault: true
        SuggestExtensions: false
    YAML
    # Minimal AST-only triggers from service_soup_test and repeated_branching_test.
    SERVICE_SOURCE = <<~RUBY
      # frozen_string_literal: true

      class OrdersController
        def create
          ValidateOrder.call(order)
          ReserveInventory.call(order)
          CapturePayment.new(order).call
        end
      end
    RUBY
    BRANCH_SOURCE = <<~RUBY
      # frozen_string_literal: true

      case order.status
      when "pending"
        nil
      when "paid", "cancelled"
        nil
      end
    RUBY
  end

  module AnalyzerSuppressionProcess
    include AnalyzerSuppressionFixtures

    def setup
      @project = File.realpath(Dir.mktmpdir("metz-scan-analyzer-suppression"))
      FileUtils.cp_r(File.join(repo_root, "test/fixtures/service_soup_app/."), @project)
      move_controller_to_workflow
      write_file(WORKFLOW, SERVICE_SOURCE)
      write_config("")
    end

    def move_controller_to_workflow
      FileUtils.mkdir_p(File.join(@project, "app/workflows"))
      FileUtils.mv(File.join(@project, "app/controllers/orders_controller.rb"), File.join(@project, WORKFLOW))
    end

    def teardown
      FileUtils.remove_entry(@project) if @project
    end

    private

    def write_file(path, body)
      FileUtils.mkdir_p(File.dirname(File.join(@project, path)))
      File.write(File.join(@project, path), body)
    end

    def write_config(body)
      write_file(".rubocop.yml", CONFIG + body)
    end

    def write_branches
      %w[a b].each { |name| write_file("app/branches/#{name}.rb", BRANCH_SOURCE) }
    end

    def cli(*)
      capture(RbConfig.ruby, File.join(repo_root, "bin/metz-scan"), *)
    end

    def rubocop(*)
      capture("rubocop", "--cache", "false", *)
    end

    def capture(*)
      @stdout, @stderr, @status = Open3.capture3(subprocess_env, "bundle", "exec", *, chdir: @project)
      [@stdout, @stderr, @status]
    end

    def subprocess_env
      { "BUNDLE_GEMFILE" => File.join(repo_root, "Gemfile"), "RUBOCOP_TARGET_RUBY_VERSION" => nil,
        "RUBOCOP_CACHE_ROOT" => File.join(repo_root, "tmp/rubocop_cache") }
    end

    def scan_report
      cli("scan", ".", "--format", "json", *scan_flags)
      assert_includes [0, 1], @status.exitstatus, @stderr
      JSON.parse(@stdout)
    end

    def scan_flags = []
    def repo_root = File.expand_path("../..", __dir__)
  end

  module AnalyzerSuppressionAssertions
    include AnalyzerSuppressionFixtures

    private

    def assert_live(report, expected)
      assert_live_counts(report, expected)
      assert_equal expected.empty? ? 0 : 1, @status.exitstatus, @stderr
      assert_equal expected.uniq.sort, report.fetch("guidance").keys.sort
    end

    def assert_live_counts(report, expected)
      assert_equal expected.sort, reported_locations(report).map(&:first).sort
      assert_equal expected.size, report.fetch("summary").fetch("offense_count")
    end

    def finding(cop, path, line)
      { "cop_name" => cop, "path" => path, "line" => line, "column" => 1,
        "message" => cop == SERVICE ? SERVICE_MESSAGE : BRANCH_MESSAGE }
    end

    def record(cop, path, line, **source)
      finding(cop, path, line).merge("suppressed_by" => source.fetch(:kind), "reason" => source[:reason],
                                     "reason_status" => source[:reason] ? "present" : "missing",
                                     "directive" => source[:directive], "config" => source[:config])
    end

    def service_records(lines, kind, **)
      lines.map { |line| record(SERVICE, WORKFLOW, line, kind: kind, **) }
    end

    def config_location(line, **)
      { "path" => ".rubocop.yml", "line" => CONFIG.lines.size + line, ** }
    end

    def assert_suppressed(report, expected, live)
      assert_equal expected, report.fetch("suppressions", [])
      assert_live(report, live)
      assert_empty(reported_locations(report) & expected.map { |entry| entry.values_at("cop_name", "path", "line") })
    end

    def reported_locations(report)
      report.fetch("files").flat_map do |file|
        file.fetch("offenses").map { |offense| report_location(file, offense) }
      end
    end

    def report_location(file, offense)
      [offense.fetch("cop_name"), file.fetch("path"), offense.fetch("location").fetch("start_line")]
    end
  end
end
