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
          @targets = options.fetch(:targets)
          @target_set = options.fetch(:target_set)
          @default_output = options.fetch(:default_output)
          @fixture_root = options.fetch(:fixture_root)
        end

        def to_h
          target_runs = targets.map { |target| TargetRun.new(target, target_set, default_output).call }
          SummaryPayload.new(target_runs, default_output, fixture_root).to_h
        end

        private

        attr_reader :targets, :target_set, :default_output, :fixture_root
      end

      class TargetRun
        def initialize(target, target_set, default_output)
          @target = target
          @scan_paths = target_set.scan_paths_for(target)
          @index = ProjectIndex.build(scan_paths)
          @default_output = default_output
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

        attr_reader :target, :scan_paths, :index, :default_output

        def identity_metadata
          { "name" => File.basename(target), "root" => target, "scan_paths" => scan_paths,
            "git" => GitMetadata.new(target).to_h, "index" => IndexMetadata.new(index).to_h }
        end

        def result_metadata
          { "project_analyzers" => project_analyzer_summary, "finding_count" => findings.size,
            "offense_count" => offenses.size }
        end

        def project_findings
          Commands::Scan::ProjectAnalyzerRunner.project_findings_for(
            scan_paths, index: index, default_output: default_output
          )
        end

        def project_analyzer_summary
          Commands::Scan::ProjectAnalyzerMetadata.summary(findings, offenses)
        end
      end

      class SummaryPayload
        def initialize(target_runs, default_output, fixture_root)
          @target_runs = target_runs
          @default_output = default_output
          @fixture_root = fixture_root
        end

        def to_h
          identity_fields.merge(target_fields).merge(project_fields)
        end

        private

        attr_reader :target_runs, :default_output, :fixture_root

        def identity_fields
          { "generated_at" => Time.now.utc.iso8601, "default_output" => default_output,
            "fixture_root" => fixture_root }
        end

        def target_fields
          { "targets" => target_runs.map(&:metadata) }
        end

        def project_fields
          { "project_analyzers" => project_analyzer_summary, "finding_count" => findings.size,
            "offense_count" => offenses.size }
        end

        def findings = target_runs.flat_map(&:findings)

        def offenses = target_runs.flat_map(&:offenses)

        def project_analyzer_summary
          Commands::Scan::ProjectAnalyzerMetadata.summary(findings, offenses)
        end
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
