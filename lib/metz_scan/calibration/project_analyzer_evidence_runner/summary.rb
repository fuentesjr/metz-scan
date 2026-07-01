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
          SummaryPayload.new(summary_payload_options(target_runs)).to_h
        end

        private

        attr_reader :options

        def target_run_for(target)
          TargetRun.new(target_run_options(target))
        end

        def target_run_options(target)
          options.slice(:target_set, :default_output, :index_builder, :finding_runner).merge(target: target)
        end

        def summary_payload_options(target_runs)
          { target_runs: target_runs, default_output: default_output, fixture_root: fixture_root,
            analyzer_names: analyzer_names, targets_file: targets_file }
        end

        def targets = options.fetch(:targets)

        def default_output = options.fetch(:default_output)

        def fixture_root = options.fetch(:fixture_root)

        def analyzer_names = options.fetch(:analyzer_names)

        def targets_file = options.fetch(:targets_file)
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
            "offense_count" => offenses.size, "breakdowns" => breakdowns,
            "notable_findings" => notable_findings }
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

        def notable_findings
          NotableFindings.new(findings, target_name: File.basename(target)).to_a
        end
      end

      class SummaryPayload
        def initialize(options)
          @options = options
        end

        def to_h
          identity_fields.merge(target_fields).merge(project_fields)
        end

        private

        attr_reader :options

        def target_runs = options.fetch(:target_runs)

        def default_output = options.fetch(:default_output)

        def fixture_root = options.fetch(:fixture_root)

        def analyzer_names = options.fetch(:analyzer_names)

        def targets_file = options.fetch(:targets_file)

        def identity_fields
          { "generated_at" => Time.now.utc.iso8601, "default_output" => default_output,
            "fixture_root" => fixture_root, "analyzer_filter" => analyzer_names,
            "targets_file" => targets_file }.compact
        end

        def target_fields
          { "targets" => target_runs.map(&:metadata) }
        end

        def project_fields
          { "project_analyzers" => project_analyzer_summary, "finding_count" => findings.size,
            "offense_count" => offenses.size, "breakdowns" => breakdowns,
            "notable_findings" => notable_findings }
        end

        def findings = target_runs.flat_map(&:findings)

        def offenses = target_runs.flat_map(&:offenses)

        def notable_findings = target_runs.flat_map { |target_run| target_run.metadata.fetch("notable_findings") }

        def project_analyzer_summary
          Commands::Scan::ProjectAnalyzerMetadata.summary(findings, offenses)
        end

        def breakdowns
          Commands::Scan::ProjectAnalyzerBreakdown.new(findings).to_h
        end
      end

      class NotableFindings
        INCLUDED_CONFIDENCES = %w[high medium].freeze
        LIMIT = 20
        private_constant :INCLUDED_CONFIDENCES, :LIMIT

        def initialize(findings, target_name:)
          @findings = findings
          @target_name = target_name
        end

        def to_a
          findings.select { |finding| notable?(finding) }
                  .sort_by { |finding| sort_key(finding) }
                  .first(LIMIT)
                  .map { |finding| finding_metadata(finding) }
        end

        private

        attr_reader :findings, :target_name

        def notable?(finding)
          INCLUDED_CONFIDENCES.include?(triage_metadata(finding)["confidence"])
        end

        def sort_key(finding)
          Commands::Scan::ProjectAnalyzerTriagePriority.sort_key(triage_metadata(finding)) +
            [finding.rule_id.to_s, finding.message.to_s]
        end

        def finding_metadata(finding)
          triage_metadata(finding).merge(identity_metadata(finding), detail_metadata(finding)).compact
        end

        def identity_metadata(finding)
          { "target" => target_name, "rule_id" => finding.rule_id, "message" => finding.message }
        end

        def detail_metadata(finding)
          { "category" => category_for(finding), "metadata" => analyzer_metadata(finding),
            "occurrence" => occurrence_metadata(finding) }
        end

        def triage_metadata(finding)
          Commands::Scan::ProjectAnalyzerMetadata.triage_metadata(finding)
        end

        def analyzer_metadata(finding)
          Commands::Scan::ProjectAnalyzerMetadata.analyzer_metadata(finding)
        end

        def category_for(finding)
          metadata = analyzer_metadata(finding)
          category_metadata_keys.filter_map { |key| metadata[key] }.first
        end

        def category_metadata_keys
          Commands::Scan::ProjectAnalyzerMetadata.category_metadata_keys
        end

        def occurrence_metadata(finding)
          occurrence = Array(finding.report_occurrences).compact.first
          return unless occurrence

          { "path" => occurrence.path, "line" => occurrence_line(occurrence),
            "context" => occurrence_context(occurrence) }.compact
        end

        def occurrence_line(occurrence)
          return occurrence.report_line if occurrence.respond_to?(:report_line)
          return occurrence.line if occurrence.respond_to?(:line)

          nil
        end

        def occurrence_context(occurrence)
          occurrence.context if occurrence.respond_to?(:context)
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
