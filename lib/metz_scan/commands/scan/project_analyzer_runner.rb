# frozen_string_literal: true

require_relative "../../analyzers/repeated_branching"
require_relative "../../analyzers/service_soup"
require_relative "../../analyzers/inheritance_descendants"
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
          Analyzers::InheritanceDescendants
        ].freeze

        module_function

        def merge(parsed, paths, index: nil)
          paths = analyzer_paths(parsed, paths)
          findings = project_findings(paths, index: index)
          return parsed if findings.empty?

          merge_findings(parsed, findings)
          parsed
        end

        def merge_findings(parsed, findings)
          offense_set = ProjectAnalyzerOffenses.build(findings)
          merge_offenses(parsed, offense_set.by_path)
          update_summary(parsed, findings, offense_set.offenses)
        end

        def project_findings(paths, index: nil)
          index ||= ProjectIndex.build(paths)
          ANALYZERS.flat_map { |analyzer| analyzer.new(paths: paths, index: index).call }
        end

        def analyzer_paths(parsed, paths)
          inspected_paths = Array(parsed["files"]).filter_map { |file| file["path"] }
          inspected_paths.empty? ? paths : inspected_paths
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
          { "path" => path, "offenses" => [] }.tap { |file| files << file }
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
