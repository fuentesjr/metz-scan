# frozen_string_literal: true

require "json"

require_relative "offense_extractor"
require_relative "../../version"

module MetzScan
  module Commands
    class Scan
      class SarifRenderer
        SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
        TOOL_URI = "https://rubygems.org/gems/metz-scan"

        def initialize(stdout, parsed)
          @stdout = stdout
          @parsed = parsed
        end

        def render
          @stdout.puts JSON.generate(to_h)
        end

        def to_h
          { "$schema" => SCHEMA, "version" => "2.1.0",
            "runs" => [{ "tool" => tool, "results" => results }] }
        end

        private

        def tool
          { "driver" => { "name" => "metz-scan", "version" => MetzScan::VERSION,
                          "informationUri" => TOOL_URI } }
        end

        def results
          OffenseExtractor.offenses(@parsed).map { |o| result_for(o) }
        end

        def result_for(offense)
          { "ruleId" => offense[:cop_name], "message" => { "text" => offense[:message] },
            "locations" => [physical_location(offense)] }
        end

        def physical_location(offense)
          { "physicalLocation" => {
            "artifactLocation" => { "uri" => offense[:path] },
            "region" => { "startLine" => offense[:line], "startColumn" => offense[:column] }
          } }
        end
      end
    end
  end
end
