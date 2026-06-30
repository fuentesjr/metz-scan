# frozen_string_literal: true

require_relative "project_analyzer_evidence_runner/artifact_writer"
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

      def self.summarize(paths: nil, default_output: false)
        targets = target_set(paths)
        targets.ensure_present!
        Summary.new(summary_options(targets, default_output)).to_h
      end

      def self.write_artifacts(summary, output_dir: default_results_path, run_id: nil)
        ArtifactWriter.new(summary: summary, output_dir: output_dir, run_id: run_id).call
      end

      def self.target_set(paths)
        TargetSet.new(paths: paths, default_apps_path: default_apps_path)
      end

      def self.summary_options(targets, default_output)
        { targets: targets.paths, target_set: targets,
          default_output: default_output, fixture_root: default_apps_path }
      end
      private_class_method :target_set, :summary_options
    end
  end
end
