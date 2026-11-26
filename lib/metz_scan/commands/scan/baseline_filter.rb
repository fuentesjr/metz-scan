# frozen_string_literal: true

require_relative "project_analyzer_metadata"
require_relative "project_analyzer_offenses"
require_relative "runner"

module MetzScan
  module Commands
    class Scan
      module BaselineMetricRules
        PUBLIC_METHODS = [
          /\bdefines (\d+) public methods \([^)]*\)(.*?\(max )\d+/i, 'defines # public methods (...)\2#'
        ].freeze
        TRAVERSAL = [/\btraversal of (\d+) exceeds (\w+) \(\d+\)/i, 'traversal of # exceeds \2 (#)'].freeze
        COLLABORATORS = [
          /\breaches into (\d+) direct collaborators \([^)]*\); Max is \d+/i,
          "reaches into # direct collaborators (...); Max is #"
        ].freeze
        BY_COP = {
          "Metz/DemeterTrainWreck" => TRAVERSAL, "Metz/ViewsDeepNavigation" => TRAVERSAL,
          "Metz/OperationsTooManyPublicMethods" => PUBLIC_METHODS, "Metz/GodServiceClass" => PUBLIC_METHODS,
          "Metz/ControllersTooManyDirectCollaborators" => COLLABORATORS,
          "MetzProject/ServiceSoup" => [/\bcoordinates (\d+) distinct services\b/i, "coordinates # distinct services"],
          "MetzProject/RepeatedBranching" => [/\bbranches in (\d+) files\b/i, "branches in # files"]
        }.freeze
        RATIO = [%r{\[(\d+)/\d+\]\z}, "[#/#]"].freeze

        module_function

        def for_cop(cop_name) = BY_COP.fetch(cop_name, RATIO)
      end

      class BaselineFilter
        def self.apply!(parsed, baseline, analyzer_entries: nil)
          new(parsed, baseline, analyzer_entries: analyzer_entries).apply!
        end

        def initialize(parsed, baseline, analyzer_entries: nil)
          @parsed = parsed
          @baseline = baseline
          @analyzer_entries = analyzer_entries
          @cursors = Hash.new(0)
          @counts = { new: 0, grown: 0, pre_existing: 0 }
        end

        def apply!
          filter_offenses!
          filter_suppressions!
          update_summary!
          parsed
        end

        private

        attr_reader :parsed, :baseline

        def base_offenses = @base_offenses ||= index_baseline_offenses

        def index_baseline_offenses
          grouped = {}
          Array(baseline["files"]).each { |file| index_file_offenses(grouped, file) }
          grouped.transform_values { |list| list.sort_by { |offense| sort_key(offense) } }
        end

        def index_file_offenses(grouped, file)
          path = normalize_path(file.fetch("path"))
          Array(file["offenses"]).each { |offense| (grouped[offense_key(path, offense)] ||= []) << offense }
        end

        def filter_offenses!
          Array(parsed["files"]).each do |file|
            path = normalize_path(file.fetch("path"))
            file["offenses"] = Array(file["offenses"]).sort_by { |o| sort_key(o) }.select { |o| keep_offense?(path, o) }
          end
        end

        def keep_offense?(path, offense)
          base = next_baseline_offense(offense_key(path, offense))
          return record_delta_offense?(offense, "new", :new) unless base
          return record_delta_offense?(offense, "grew", :grown) if grew?(offense, base)

          @counts[:pre_existing] += 1
          false
        end

        def next_baseline_offense(key) = base_offenses[key]&.at((@cursors[key] += 1) - 1)

        def record_delta_offense?(offense, status, counter)
          offense["baseline_status"] = status
          @counts[counter] += 1
          true
        end

        def grew?(offense, base)
          cur = offense_metric(offense)
          prev = offense_metric(base)
          cur && prev && cur > prev
        end

        def offense_metric(offense)
          pattern, _mask = rule_for(offense.fetch("cop_name"))
          stripped_message(offense)[pattern, 1]&.to_i
        end

        def normalized_message(offense)
          pattern, mask = rule_for(offense.fetch("cop_name"))
          stripped_message(offense).sub(pattern, mask)
        end

        def rule_for(cop_name) = BaselineMetricRules.for_cop(cop_name)

        def stripped_message(offense) = offense.fetch("message").delete_prefix("#{offense.fetch('cop_name')}: ")

        def offense_key(path, offense) = [path, offense.fetch("cop_name"), normalized_message(offense)]

        def sort_key(offense) = (offense["location"] || {}).values_at("start_line", "start_column").map(&:to_i)

        def normalize_path(path) = Runner.display_path(File.expand_path(path))

        def filter_suppressions!
          return unless parsed["suppressions"].is_a?(Array)

          tally = Array(baseline["suppressions"]).each_with_object(Hash.new(0)) { |s, c| c[suppression_key(s)] += 1 }
          parsed["suppressions"].reject! { |item| drop_suppression?(tally, suppression_key(item)) }
        end

        def drop_suppression?(tally, key) = tally[key].positive? && (tally[key] -= 1) >= 0

        def suppression_key(item)
          [item["path"] && normalize_path(item["path"]), *item.values_at("cop_name", "suppressed_by", "reason")]
        end

        def update_summary!
          summary = parsed["summary"] ||= {}
          summary.merge!("offense_count" => @counts[:new] + @counts[:grown], "baseline" => baseline_summary)
          update_project_analyzers!(summary) if summary.key?("project_analyzers")
        end

        def baseline_summary
          { "pre_existing_offense_count" => @counts[:pre_existing], "new_offense_count" => @counts[:new],
            "grown_offense_count" => @counts[:grown] }
        end

        def update_project_analyzers!(summary)
          all_offenses = Array(parsed["files"]).flat_map { |file| Array(file["offenses"]) }
          findings, offenses = ProjectAnalyzerOffenses.filter_entries(@analyzer_entries, all_offenses)
          return summary.delete("project_analyzers") if findings.empty?

          summary["project_analyzers"] = ProjectAnalyzerMetadata.summary(findings, offenses)
        end
      end
    end
  end
end
