# frozen_string_literal: true

require_relative "offense_extractor"
require_relative "project_analyzer_triage_formatter"

module MetzScan
  module Commands
    class Scan
      class GithubAnnotationsRenderer
        ERROR_SEVERITIES = %w[error fatal].freeze

        def initialize(stdout, parsed)
          @stdout = stdout
          @parsed = parsed
        end

        def render
          OffenseExtractor.offenses(@parsed).each { |offense| stdout.puts annotation_for(offense) }
        end

        private

        attr_reader :stdout

        def annotation_for(offense)
          "::#{level_for(offense)} #{properties_for(offense)}::#{escape_data(message_for(offense))}"
        end

        def level_for(offense)
          ERROR_SEVERITIES.include?(offense[:severity].to_s) ? "error" : "warning"
        end

        def properties_for(offense)
          annotation_properties(offense).map { |key, value| "#{key}=#{escape_property(value)}" }.join(",")
        end

        def annotation_properties(offense)
          { file: offense[:path], line: offense[:line], col: offense[:column], title: offense[:cop_name] }.compact
        end

        def message_for(offense)
          [offense[:message], ProjectAnalyzerTriageFormatter.line(offense[:project_analyzer])].compact.join("\n")
        end

        def escape_property(value)
          escape_data(value).gsub(":", "%3A").gsub(",", "%2C")
        end

        def escape_data(value)
          value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
        end
      end
    end
  end
end
