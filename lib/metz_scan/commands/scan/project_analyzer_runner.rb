# frozen_string_literal: true

require "rubocop"

require_relative "../../analyzers/repeated_branching"
require_relative "../../analyzers/service_soup"
require_relative "../../analyzers/inheritance_descendants"
require_relative "../../analyzers/package_dependency_pressure"
require_relative "../../analyzers/namespace_leak_pressure"
require_relative "../../analyzers/implicit_context_pressure"
require_relative "../../project_index"
require_relative "project_analyzer_metadata"
require_relative "project_analyzer_offenses"

module MetzScan
  module Commands
    class Scan
      # Runs wrapper-level project analyzers and merges their findings into the
      # same report shape produced by RuboCop's JSON formatter.
      module ProjectAnalyzerRunner
        ANALYZERS = [
          Analyzers::RepeatedBranching,
          Analyzers::ServiceSoup,
          Analyzers::InheritanceDescendants,
          Analyzers::PackageDependencyPressure,
          Analyzers::NamespaceLeakPressure,
          Analyzers::ImplicitContextPressure
        ].freeze
        INDEX_BACKED_ANALYZERS = [
          Analyzers::InheritanceDescendants,
          Analyzers::PackageDependencyPressure,
          Analyzers::NamespaceLeakPressure
        ].freeze
        DEFAULT_OUTPUT_STATUS = "validated"
        DEFAULT_OUTPUT_CONFIDENCE = "medium"
        DEFAULT_OUTPUT_TRIAGE_SEVERITY = "design pressure"

        module_function

        def merge!(parsed, paths, index: nil, default_output: false)
          findings = project_findings_for(paths, index: index, default_output: default_output)
          return parsed if findings.empty?

          merge_findings(parsed, findings)
          parsed
        end

        def project_findings_for(paths, index: nil, default_output: false)
          paths = analyzer_paths(paths, index: index)
          return [] if paths.empty? && !index

          findings = project_findings(paths, index: index, default_output: default_output)
          default_output ? findings.select { |finding| default_output_finding?(finding) } : findings
        end

        def merge_findings(parsed, findings)
          offense_set = ProjectAnalyzerOffenses.build(findings)
          merge_offenses(parsed, offense_set.by_path)
          update_summary(parsed, findings, offense_set.offenses)
        end

        def project_findings(paths, index: nil, default_output: false)
          analyzers = analyzers_for(default_output: default_output)
          index = project_index_for(paths, index, analyzers)
          analyzers.flat_map { |analyzer| analyzer.new(paths: paths, index: index).call }
        end

        def analyzers_for(default_output:)
          return ANALYZERS unless default_output

          ANALYZERS.select { |analyzer| default_output_analyzer?(analyzer) }
        end

        def default_output_analyzer?(analyzer)
          analyzer.const_defined?(:DEFAULT_OUTPUT_ELIGIBLE) &&
            analyzer::DEFAULT_OUTPUT_ELIGIBLE &&
            analyzer.const_defined?(:PROJECT_ANALYZER_STATUS) &&
            analyzer::PROJECT_ANALYZER_STATUS == DEFAULT_OUTPUT_STATUS
        end

        def project_index_for(paths, index, analyzers)
          return index if index
          return nil unless analyzers.any? { |analyzer| INDEX_BACKED_ANALYZERS.include?(analyzer) }

          ProjectIndex.build(paths)
        end

        def default_output_finding?(finding)
          finding.project_analyzer_status == DEFAULT_OUTPUT_STATUS &&
            finding.confidence == DEFAULT_OUTPUT_CONFIDENCE &&
            finding.triage_severity == DEFAULT_OUTPUT_TRIAGE_SEVERITY
        end

        def analyzer_paths(paths, index: nil)
          return Array(paths) if index

          rubocop_target_files(paths)
        end

        def rubocop_target_files(paths)
          RuboCop::TargetFinder.new(RuboCop::ConfigStore.new, {}).find(paths, :all_file_types)
        end

        def merge_offenses(parsed, grouped_offenses)
          grouped_offenses.each do |path, offenses|
            file_for(parsed, path)["offenses"].concat(offenses)
          end
        end

        def file_for(parsed, path)
          files = parsed["files"] ||= []
          files.find { |file| same_path?(file["path"], path) } || append_file(files, path)
        end

        def same_path?(left, right)
          File.expand_path(left) == File.expand_path(right)
        end

        def append_file(files, path)
          { "path" => display_path(path), "offenses" => [] }.tap { |file| files << file }
        end

        def display_path(path)
          expanded_path = File.expand_path(path)
          cwd = "#{File.expand_path(Dir.pwd)}#{File::SEPARATOR}"
          return expanded_path.delete_prefix(cwd) if expanded_path.start_with?(cwd)

          path
        end

        def update_summary(parsed, findings, project_offenses)
          summary = parsed["summary"] ||= {}
          files = Array(parsed["files"])
          summary["offense_count"] = files.sum { |file| Array(file["offenses"]).size }
          update_file_counts(summary, files.size)
          summary["project_analyzers"] = ProjectAnalyzerMetadata.summary(findings, project_offenses)
        end

        def update_file_counts(summary, file_count)
          summary["target_file_count"] = [summary["target_file_count"].to_i, file_count].max
          summary["inspected_file_count"] = [summary["inspected_file_count"].to_i, file_count].max
        end
      end
    end
  end
end
