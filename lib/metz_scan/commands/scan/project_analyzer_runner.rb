# frozen_string_literal: true

require_relative "../../analyzers/repeated_branching"
require_relative "../../analyzers/service_soup"

module MetzScan
  module Commands
    class Scan
      # Runs wrapper-level project analyzers and merges their findings into the
      # same report shape produced by RuboCop's JSON formatter.
      module ProjectAnalyzerRunner
        ANALYZERS = [
          Analyzers::RepeatedBranching,
          Analyzers::ServiceSoup
        ].freeze

        module_function

        def merge(parsed, paths)
          findings = project_findings(analyzer_paths(parsed, paths))
          return parsed if findings.empty?

          merge_offenses(parsed, offenses_by_path(findings))
          update_summary(parsed)
          parsed
        end

        def project_findings(paths)
          ANALYZERS.flat_map { |analyzer| analyzer.new(paths: paths).call }
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

        def offenses_by_path(findings)
          findings.flat_map { |finding| offenses_for(finding) }
                  .group_by { |entry| entry.fetch(:path) }
                  .transform_values { |entries| entries.map { |entry| entry.fetch(:offense) } }
        end

        def offenses_for(finding)
          locations_for(finding).map do |location|
            { path: location.fetch(:path), offense: offense_for(finding, location.fetch(:line)) }
          end
        end

        def locations_for(finding)
          Array(finding.occurrences).filter_map do |occurrence|
            next unless occurrence.respond_to?(:path) && occurrence.path

            { path: occurrence.path, line: occurrence.respond_to?(:line) ? occurrence.line : 1 }
          end.uniq
        end

        def offense_for(finding, line)
          offense_metadata(finding).merge("location" => location_hash(line))
        end

        def offense_metadata(finding)
          add_project_analyzer_metadata(common_offense_metadata(finding), finding)
        end

        def common_offense_metadata(finding)
          basic_offense_metadata(finding).merge(explanation_metadata(finding))
        end

        def basic_offense_metadata(finding)
          { "cop_name" => finding.rule_id, "message" => finding.message,
            "severity" => "refactor", "corrected" => false, "correctable" => false }
        end

        def explanation_metadata(finding)
          { "why_it_matters" => finding.why_it_matters, "fix_safety" => "manual",
            "suggested_next_moves" => suggested_next_moves_for(finding) }
        end

        def add_project_analyzer_metadata(metadata, finding)
          project_metadata = project_analyzer_metadata_for(finding)
          return metadata if project_metadata.empty?

          metadata.merge("project_analyzer" => project_metadata)
        end

        def project_analyzer_metadata_for(finding)
          return {} unless finding.respond_to?(:project_analyzer_metadata)

          finding.project_analyzer_metadata || {}
        end

        def suggested_next_moves_for(finding)
          return [] unless finding.respond_to?(:suggested_next_moves)

          Array(finding.suggested_next_moves).map(&:to_s)
        end

        def location_hash(line)
          line ||= 1
          { "start_line" => line, "start_column" => 1, "last_line" => line,
            "last_column" => 1, "length" => 1, "line" => line, "column" => 1 }
        end

        def update_summary(parsed)
          summary = parsed["summary"] ||= {}
          files = Array(parsed["files"])
          summary["offense_count"] = files.sum { |file| Array(file["offenses"]).size }
          update_file_counts(summary, files.size)
        end

        def update_file_counts(summary, file_count)
          summary["target_file_count"] = [summary["target_file_count"].to_i, file_count].max
          summary["inspected_file_count"] = [summary["inspected_file_count"].to_i, file_count].max
        end
      end
    end
  end
end
