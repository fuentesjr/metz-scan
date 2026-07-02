# frozen_string_literal: true

require_relative "../../commands/scan/project_analyzer_runner"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class ReadinessCatalog
        NOTES = {
          "MetzProject/ServiceSoup" => {
            "evidence" => "Medium design-pressure findings are calibrated; setup orchestration is downranked.",
            "next" => "Monitor future calibration for setup noise or new service-call shapes.",
            "not_next" => "Do not reopen promotion unless default-output evidence regresses."
          },
          "MetzProject/RepeatedBranching" => {
            "evidence" => "Repeated branch tables are calibrated; generic subjects are lower-confidence.",
            "next" => "Monitor generic-subject calibration and branch-subject readability.",
            "not_next" => "Do not expand branch parsing without sparse fixture-backed evidence."
          },
          "MetzProject/DeepInheritanceTree" => {
            "evidence" => "Useful inheritance spread evidence remains dependent on the optional project index.",
            "next" => "Use opt-in calibration to watch grouped output and broad-root downranking.",
            "not_next" => "Do not make default-output eligible while findings depend on optional indexing."
          },
          "MetzProject/PackageDependencyPressure" => {
            "evidence" => "Current active fixtures show 39 findings: 1 medium package boundary and " \
                          "38 low shared dependencies.",
            "next" => "Reopen when new targets can produce independent medium package-boundary evidence.",
            "not_next" => "Do not promote, retune thresholds, or downrank the sole medium finding from this sample."
          },
          "MetzProject/NamespaceLeakPressure" => {
            "evidence" => "Shared-namespace downranking improved triage, but medium evidence is still narrow.",
            "next" => "Calibrate broader namespace-boundary samples before status or default-output discussion.",
            "not_next" => "Do not promote or add app-specific namespace suppressions from sparse evidence."
          },
          "MetzProject/ImplicitContextPressure" => {
            "evidence" => "Current active fixtures show 11 findings dominated by mechanical framework state: " \
                          "9 mechanical, 1 useful execution-identity prompt, and 1 needs-context fallback.",
            "next" => "Keep candidate-only and use broader samples to separate boundary setup from ambient identity " \
                      "design pressure.",
            "not_next" => "Do not add suppressions, global-access forms, promotion, or default-output eligibility " \
                          "from this sample."
          },
          "MetzProject/RepeatedQueryCriteria" => {
            "evidence" => "Current active fixtures show 15 findings: 12 useful prompts and 3 mechanical lookups.",
            "next" => "Keep separating membership-table lookups from business-named lookup concepts.",
            "not_next" => "Do not add more query forms, dynamic receivers, association receivers, SQL strings, " \
                          "joins, merges, Arel, single-key finders, bang finders, exists?, or take."
          },
          "MetzProject/SubclassOverridePressure" => {
            "evidence" => "Current active fixtures show 106 findings: 76 low broad-root and " \
                          "30 medium manual-review findings.",
            "next" => "Refine medium-family evidence only when it supports a generic, non-app-specific rule.",
            "not_next" => "Do not promote, make default-output eligible, suppress medium categories, or " \
                          "retune thresholds."
          }
        }.freeze

        def initialize(analyzer_names: [], analyzers: Commands::Scan::ProjectAnalyzerRunner::ANALYZERS)
          @analyzer_names = Array(analyzer_names)
          @analyzers = analyzers
        end

        def to_a
          selected_analyzers.filter_map { |analyzer| readiness_entry(analyzer) }
        end

        private

        attr_reader :analyzer_names, :analyzers

        def selected_analyzers
          return analyzers if analyzer_names.empty?

          analyzers.select { |analyzer| analyzer_names.include?(rule_id_for(analyzer)) }
        end

        def readiness_entry(analyzer)
          note = NOTES[rule_id_for(analyzer)]
          return unless note

          analyzer_fields(analyzer).merge(note)
        end

        def analyzer_fields(analyzer)
          status = analyzer::PROJECT_ANALYZER_STATUS
          default_output = Commands::Scan::ProjectAnalyzerRunner.default_output_analyzer?(analyzer)

          { "rule_id" => rule_id_for(analyzer), "status" => status, "default_output" => default_output,
            "disposition" => disposition_for(status, default_output) }
        end

        def rule_id_for(analyzer)
          analyzer::RULE_ID
        end

        def disposition_for(status, default_output)
          "#{status_label(status)}; #{default_output_label(default_output)}."
        end

        def status_label(status)
          return "Candidate-only" if status == "candidate"
          return "Validated opt-in" if status == "validated"

          status.to_s
        end

        def default_output_label(default_output)
          default_output ? "default-output eligible" : "not default-output eligible"
        end
      end
    end
  end
end
