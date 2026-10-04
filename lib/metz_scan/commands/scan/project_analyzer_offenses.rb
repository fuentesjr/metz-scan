# frozen_string_literal: true

require_relative "project_analyzer_metadata"

module MetzScan
  module Commands
    class Scan
      module ProjectAnalyzerOffenses
        OffenseSet = Struct.new(:by_path, :offenses, keyword_init: true)

        module_function

        def build(findings)
          entries = entries_for(findings)
          OffenseSet.new(by_path: offenses_by_path(entries), offenses: entries.map { |entry| entry.fetch(:offense) })
        end

        def entries_for(findings)
          findings.flat_map { |finding| offenses_for(finding) }
        end

        def offenses_for(finding)
          locations_for(finding).map do |location|
            { path: location.path, offense: offense_for(finding, location) }
          end
        end

        def locations_for(finding)
          Array(finding.report_occurrences).compact.uniq
        end

        def offense_for(finding, occurrence)
          offense_metadata(finding, occurrence).merge("location" => location_hash(occurrence.report_line))
        end

        def offense_metadata(finding, occurrence)
          add_project_analyzer_metadata(common_offense_metadata(finding), finding, occurrence)
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

        def add_project_analyzer_metadata(metadata, finding, occurrence)
          project_metadata = ProjectAnalyzerMetadata.offense_metadata(finding)
          return metadata if project_metadata.empty?

          metadata.merge("project_analyzer" => project_metadata.merge(report_location_metadata(occurrence)))
        end

        def report_location_metadata(occurrence)
          { "report_location" => { "line_source" => occurrence.line_source,
                                   "context" => occurrence.context }.compact }
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

        def offenses_by_path(entries)
          entries.group_by { |entry| entry.fetch(:path) }
                 .transform_values { |grouped_entries| grouped_entries.map { |entry| entry.fetch(:offense) } }
        end
      end
    end
  end
end
