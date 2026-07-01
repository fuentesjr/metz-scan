# frozen_string_literal: true

require "open3"
require "time"

require_relative "../../project_index"
require_relative "../../commands/scan/project_analyzer_metadata"
require_relative "../../commands/scan/project_analyzer_offenses"
require_relative "../../commands/scan/project_analyzer_runner"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class Summary
        def initialize(options)
          @options = options
        end

        def to_h
          target_runs = targets.map { |target| target_run_for(target).call }
          SummaryPayload.new(target_runs, default_output, fixture_root, analyzer_names).to_h
        end

        private

        attr_reader :options

        def target_run_for(target)
          TargetRun.new(target_run_options(target))
        end

        def target_run_options(target)
          options.slice(:target_set, :default_output, :index_builder, :finding_runner).merge(target: target)
        end

        def targets = options.fetch(:targets)

        def default_output = options.fetch(:default_output)

        def fixture_root = options.fetch(:fixture_root)

        def analyzer_names = options.fetch(:analyzer_names)
      end

      class TargetRun
        def initialize(options)
          @options = options
        end

        attr_reader :findings, :offenses

        def call
          @findings = project_findings
          @offenses = Commands::Scan::ProjectAnalyzerOffenses.build(findings).offenses
          self
        end

        def metadata
          identity_metadata.merge(result_metadata)
        end

        private

        attr_reader :options

        def target = options.fetch(:target)

        def target_set = options.fetch(:target_set)

        def default_output = options.fetch(:default_output)

        def finding_runner = options.fetch(:finding_runner)

        def scan_paths
          @scan_paths ||= target_set.scan_paths_for(target)
        end

        def index
          @index ||= index_for(options.fetch(:index_builder))
        end

        def index_for(index_builder)
          return NoScanIndex.new if scan_paths.empty?

          index_builder.call(scan_paths)
        end

        def identity_metadata
          { "name" => File.basename(target), "root" => target, "scan_paths" => scan_paths,
            "git" => GitMetadata.new(target).to_h, "index" => IndexMetadata.new(index).to_h }
        end

        def result_metadata
          { "project_analyzers" => project_analyzer_summary, "finding_count" => findings.size,
            "offense_count" => offenses.size, "breakdowns" => breakdowns }
        end

        def project_findings
          return [] if scan_paths.empty?

          finding_runner.call(scan_paths, index: index, default_output: default_output)
        end

        def project_analyzer_summary
          Commands::Scan::ProjectAnalyzerMetadata.summary(findings, offenses)
        end

        def breakdowns
          Commands::Scan::ProjectAnalyzerBreakdown.new(findings).to_h
        end
      end

      class SummaryPayload
        def initialize(target_runs, default_output, fixture_root, analyzer_names)
          @target_runs = target_runs
          @default_output = default_output
          @fixture_root = fixture_root
          @analyzer_names = analyzer_names
        end

        def to_h
          identity_fields.merge(target_fields).merge(project_fields)
        end

        private

        attr_reader :target_runs, :default_output, :fixture_root, :analyzer_names

        def identity_fields
          { "generated_at" => Time.now.utc.iso8601, "default_output" => default_output,
            "fixture_root" => fixture_root, "analyzer_filter" => analyzer_names }
        end

        def target_fields
          { "targets" => target_runs.map(&:metadata) }
        end

        def project_fields
          { "project_analyzers" => project_analyzer_summary, "finding_count" => findings.size,
            "offense_count" => offenses.size, "breakdowns" => breakdowns }
        end

        def findings = target_runs.flat_map(&:findings)

        def offenses = target_runs.flat_map(&:offenses)

        def project_analyzer_summary
          Commands::Scan::ProjectAnalyzerMetadata.summary(findings, offenses)
        end

        def breakdowns
          Commands::Scan::ProjectAnalyzerBreakdown.new(findings).to_h
        end
      end

      class NoScanIndex
        def backend_name = :none

        def available? = false

        def reason = "no top-level app/ or lib/ scan paths under calibration target"

        def indexed_files = []

        def index_errors = []

        def diagnostics = []
      end

      class IndexMetadata
        def initialize(index)
          @index = index
        end

        def to_h
          availability_fields.merge(count_fields).compact
        end

        private

        attr_reader :index

        def availability_fields
          { "backend" => index.backend_name.to_s, "available" => index.available?,
            "reason" => index.reason }
        end

        def count_fields
          { "indexed_file_count" => index.indexed_files.size, "index_error_count" => index.index_errors.size,
            "diagnostic_count" => index.diagnostics.size }
        end
      end

      class GitMetadata
        def initialize(target)
          @target = target
        end

        def to_h
          { "branch" => git_capture("branch", "--show-current"),
            "revision" => git_capture("rev-parse", "HEAD") }.compact
        end

        private

        attr_reader :target

        def git_capture(*)
          stdout, _stderr, status = Open3.capture3("git", "-C", target, *)
          return unless status.success?

          stdout.strip.then { |value| value unless value.empty? }
        end
      end
    end
  end
end
