# frozen_string_literal: true

require "psych"
require "rubocop"

require "metz_scan/commands/scan/config_disables"
require "metz_scan/commands/scan/config_exclusions"
require "metz_scan/commands/scan/inline_directive_locator"
require "metz_scan/commands/scan/project_config_scope"

module MetzScan
  module Commands
    class Scan
      # Default mode asks RuboCop to --display-suppressed, then partitions every
      # offense: a project `Enabled: false` or per-cop Exclude hides it
      # (credited even when an inline disable also covers it), else an inline
      # directive hides it, else it is live. Hidden offenses leave `files` and
      # the counts; the ones a project wrote a suppression for are listed under
      # `suppressions`.
      class SuppressionLedger
        SORT_KEYS = %w[path line column cop_name].freeze

        def self.apply(report)
          store = ProjectConfigScope.store
          new(report, [ConfigDisables.new(store), ConfigExclusions.new(store)]).apply
        rescue RuboCop::Error, Psych::Exception
          # Invalid project config leaves no project config to honor, matching
          # the forced-default target-discovery fallback.
          new(report, []).apply
        end

        def initialize(report, config_sources)
          @report = report
          @config_sources = config_sources
          @directives = InlineDirectiveLocator.new
          @records = []
        end

        def apply
          files = Array(report["files"]).map { |file| file.merge("offenses" => live_offenses(file)) }
          recount(report.merge("files" => files, "suppressions" => records.sort_by { |r| r.values_at(*SORT_KEYS) }))
        end

        private

        attr_reader :report, :config_sources, :directives, :records

        def live_offenses(file)
          path = file.fetch("path")
          sourced = Array(file["offenses"]).map { |offense| [offense, suppression_source(path, offense)] }
          live, hidden = sourced.partition { |_offense, source| source.nil? }
          hidden.each { |offense, source| record(path, offense, source.record_fields(path, offense)) }
          live.map(&:first)
        end

        def suppression_source(path, offense)
          config_source = config_sources.find { |source| source.scoped_off?(path, offense) }
          config_source || (directives if offense["suppressed"])
        end

        # Hidden offenses with no project-written suppression (stock-default
        # scope, synthetic opt-in coverage) produce no record.
        def record(path, offense, fields)
          records << finding(path, offense).merge(fields) if fields
        end

        def finding(path, offense)
          location = offense.fetch("location")
          { "cop_name" => offense.fetch("cop_name"), "path" => path, "line" => location.fetch("start_line"),
            "column" => location.fetch("start_column"), "message" => offense.fetch("message") }
        end

        def recount(report)
          count = report["files"].sum { |file| file["offenses"].size }
          report.merge("summary" => report.fetch("summary").merge("offense_count" => count))
        end
      end
    end
  end
end
