# frozen_string_literal: true

require_relative "project_analyzer_evidence_runner/artifact_writer"
require_relative "project_analyzer_evidence_runner/collaborators"
require_relative "project_analyzer_evidence_runner/markdown_renderer"
require_relative "project_analyzer_evidence_runner/summary"
require_relative "project_analyzer_evidence_runner/target_set"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class Error < StandardError; end

      DEFAULT_APPS_PATH = File.join("tmp", "project-analyzer-calibration", "apps").freeze
      DEFAULT_RESULTS_PATH = File.join("tmp", "project-analyzer-calibration", "results").freeze

      def self.default_apps_path = File.expand_path(DEFAULT_APPS_PATH)

      def self.default_results_path = File.expand_path(DEFAULT_RESULTS_PATH)

      def self.summarize(**options)
        options = summarize_options(options)
        targets = target_set(options[:paths], options[:targets_file])
        resolved_summary_options = summary_options(targets, options)
        targets.ensure_present!
        Summary.new(resolved_summary_options).to_h
      end

      def self.write_artifacts(summary, output_dir: default_results_path, run_id: nil)
        ArtifactWriter.new(summary: summary, output_dir: output_dir, run_id: run_id).call
      end

      def self.target_set(paths, targets_file)
        TargetSet.new(paths: paths, default_apps_path: default_apps_path, targets_file: targets_file)
      end

      def self.summarize_options(options)
        { paths: nil, default_output: false, analyzer_names: nil, targets_file: nil,
          index_builder: nil, finding_runner: nil }.merge(options)
      end

      def self.summary_options(targets, options)
        analyzer_names = Array(options[:analyzer_names]).compact
        analyzers = AnalyzerSelection.new(analyzer_names).call
        base_summary_options(targets, options[:default_output], analyzer_names)
          .merge(collaborator_options(options, analyzers))
      end

      def self.collaborator_options(options, analyzers)
        { index_builder: options[:index_builder] || ProjectIndex.method(:build),
          finding_runner: options[:finding_runner] || FindingRunner.new(analyzers: analyzers) }
      end

      def self.base_summary_options(targets, default_output, analyzer_names)
        { targets: targets.paths, target_set: targets,
          default_output: default_output, fixture_root: default_apps_path,
          analyzer_names: analyzer_names, targets_file: targets.targets_file }
      end
      private_class_method :target_set, :summary_options
      private_class_method :base_summary_options
    end
  end
end
