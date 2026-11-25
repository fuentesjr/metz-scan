# frozen_string_literal: true

require_relative "../../analyzers/repeated_branching"
require_relative "../../analyzers/service_soup"
require_relative "../../analyzers/inheritance_descendants"
require_relative "../../analyzers/package_dependency_pressure"
require_relative "../../analyzers/namespace_leak_pressure"
require_relative "../../analyzers/implicit_context_pressure"
require_relative "../../analyzers/repeated_query_criteria"
require_relative "../../analyzers/source_cache"
require_relative "../../analyzers/subclass_override_pressure"
require_relative "../../analyzers/test_calls_private_method"
require_relative "../../project_index"
require_relative "runner"
require_relative "project_analyzer_metadata"
require_relative "project_analyzer_offenses"

module MetzScan
  module Commands
    class Scan
      # Runs wrapper-level project analyzers and merges their findings into the
      # same report shape produced by RuboCop's JSON formatter.
      module ProjectAnalyzerRunner
        ANALYZERS = [
          Analyzers::RepeatedBranching, Analyzers::ServiceSoup, Analyzers::InheritanceDescendants,
          Analyzers::PackageDependencyPressure, Analyzers::NamespaceLeakPressure, Analyzers::ImplicitContextPressure,
          Analyzers::RepeatedQueryCriteria, Analyzers::SubclassOverridePressure, Analyzers::TestCallsPrivateMethod
        ].freeze
        DEFAULT_OUTPUT_STATUS = "validated"
        DEFAULT_OUTPUT_CONFIDENCE = "medium"
        DEFAULT_OUTPUT_TRIAGE_SEVERITY = "design pressure"

        module_function

        def merge!(parsed, paths, analyzer_entries: nil, **options)
          scope = TargetFileDiscovery.analyzer_scope(options)
          findings = project_findings_for(paths, **options, **scope)
          return parsed if findings.empty?

          merge_live_offenses(parsed, findings, scope, analyzer_entries)
        end

        def merge_live_offenses(parsed, findings, scope, analyzer_entries = nil)
          offense_set = Runner.with_errors { ProjectAnalyzerOffenses.build(findings, ledger_report: parsed, **scope) }
          return parsed if offense_set.findings.empty?

          analyzer_entries&.concat(offense_set.pairs)
          merge_offense_set(parsed, offense_set)
          parsed
        end

        def project_findings_for(paths, index: nil, default_output: false, **options)
          paths = analyzer_paths(paths, index: index, **options)
          return [] if paths.empty? && !index

          store = options[:rubocop_store] || options[:store]
          findings = project_findings(paths, index: index, default_output: default_output, config_store: store)
          default_output ? findings.select { |finding| default_output_finding?(finding) } : findings
        end

        def merge_offense_set(parsed, offense_set)
          merge_offenses(parsed, offense_set.by_path)
          update_summary(parsed, offense_set.findings, offense_set.offenses)
        end

        def project_findings(paths, index: nil, default_output: false, config_store: nil)
          analyzers = analyzers_for(default_output: default_output)
          index = project_index_for(paths, index, analyzers)
          Analyzers::SourceCache.with(config_store: config_store) do
            analyzers.flat_map { |analyzer| analyzer.new(paths: paths, index: index).call }
          end
        end

        def analyzers_for(default_output:)
          default_output ? ANALYZERS.select { |analyzer| default_output_analyzer?(analyzer) } : ANALYZERS
        end

        def default_output_analyzer?(analyzer)
          analyzer.const_defined?(:DEFAULT_OUTPUT_ELIGIBLE) &&
            analyzer::DEFAULT_OUTPUT_ELIGIBLE &&
            analyzer.const_defined?(:PROJECT_ANALYZER_STATUS) &&
            analyzer::PROJECT_ANALYZER_STATUS == DEFAULT_OUTPUT_STATUS
        end

        def index_backed_analyzer?(analyzer) = analyzer.const_defined?(:USES_INDEX) && analyzer::USES_INDEX

        def index_backed_analyzers = ANALYZERS.select { |analyzer| index_backed_analyzer?(analyzer) }

        def project_index_for(paths, index, analyzers)
          return index if index
          return nil unless analyzers.any? { |analyzer| index_backed_analyzer?(analyzer) }

          ProjectIndex.build(paths)
        end

        def default_output_finding?(finding)
          finding.project_analyzer_status == DEFAULT_OUTPUT_STATUS &&
            finding.confidence == DEFAULT_OUTPUT_CONFIDENCE &&
            finding.triage_severity == DEFAULT_OUTPUT_TRIAGE_SEVERITY
        end

        def analyzer_paths(paths, index: nil, target_files: nil, **)
          return Array(paths) if index
          return target_files if target_files

          rubocop_target_files(paths, **)
        end

        def rubocop_target_files(paths, **) = Runner.with_errors { TargetFileDiscovery.for_analyzer(paths, **) }

        def merge_offenses(parsed, grouped_offenses)
          grouped_offenses.each do |path, offenses|
            file_for(parsed, path)["offenses"].concat(offenses)
          end
        end

        def file_for(parsed, path)
          files = parsed["files"] ||= []
          files.find { |file| same_path?(file["path"], path) } || append_file(files, path)
        end

        def same_path?(left, right) = File.expand_path(left) == File.expand_path(right)

        def append_file(files, path) = { "path" => display_path(path), "offenses" => [] }.tap { |file| files << file }

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
