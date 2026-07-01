# frozen_string_literal: true

require_relative "../../project_index"
require_relative "../../commands/scan/project_analyzer_runner"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class AnalyzerSelection
        def initialize(rule_ids)
          @rule_ids = Array(rule_ids).compact
        end

        def call
          return nil if rule_ids.empty?

          rule_ids.map { |rule_id| analyzer_for(rule_id) }
        end

        private

        attr_reader :rule_ids

        def analyzer_for(rule_id)
          analyzer = analyzers_by_rule_id[rule_id]
          raise Error, "unknown project analyzer: #{rule_id}" unless analyzer

          analyzer
        end

        def analyzers_by_rule_id
          Commands::Scan::ProjectAnalyzerRunner::ANALYZERS.to_h { |analyzer| [analyzer::RULE_ID, analyzer] }
        end
      end

      class FindingRunner
        def initialize(analyzers: nil)
          @analyzers = analyzers
        end

        def call(paths, index:, default_output:)
          return project_findings(paths, index: index, default_output: default_output) unless analyzers

          selected = selected_analyzers(default_output)
          filter_default_output(run_selected_analyzers(selected, paths, index), default_output)
        end

        private

        attr_reader :analyzers

        def project_findings(paths, index:, default_output:)
          Commands::Scan::ProjectAnalyzerRunner.project_findings_for(
            paths, index: index, default_output: default_output
          )
        end

        def selected_analyzers(default_output)
          return analyzers unless default_output

          analyzers.select { |analyzer| Commands::Scan::ProjectAnalyzerRunner.default_output_analyzer?(analyzer) }
        end

        def run_selected_analyzers(selected, paths, index)
          selected.flat_map { |analyzer| analyzer.new(paths: paths, index: index).call }
        end

        def filter_default_output(findings, default_output)
          return findings unless default_output

          findings.select { |finding| Commands::Scan::ProjectAnalyzerRunner.default_output_finding?(finding) }
        end
      end
    end
  end
end
