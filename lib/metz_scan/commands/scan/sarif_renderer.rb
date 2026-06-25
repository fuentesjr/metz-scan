# frozen_string_literal: true

require "digest"
require "json"

require_relative "offense_extractor"
require_relative "sarif_rule_descriptors"
require_relative "sarif_severity"
require_relative "../../version"

module MetzScan
  module Commands
    class Scan
      class SarifRenderer
        SCHEMA = "https://json.schemastore.org/sarif-2.1.0.json"
        TOOL_URI = "https://github.com/fuentesjr/metz-scan"
        ROOT_URI_BASE_ID = "ROOT"

        def initialize(stdout, parsed)
          @stdout = stdout
          @parsed = parsed
        end

        def render
          @stdout.puts JSON.generate(to_h)
        end

        def to_h
          { "$schema" => SCHEMA, "version" => "2.1.0",
            "runs" => [{ "tool" => tool, "results" => results,
                         "originalUriBaseIds" => original_uri_base_ids }] }
        end

        private

        def tool
          { "driver" => { "name" => "metz-scan", "version" => MetzScan::VERSION,
                          "informationUri" => TOOL_URI, "rules" => reporting_descriptors } }
        end

        def results
          offenses.map { |offense| result_for(offense) }
        end

        def result_for(offense)
          base_result(offense).tap { |result| add_project_analyzer_properties(result, offense) }
        end

        def base_result(offense)
          { "ruleId" => offense[:cop_name], "level" => level_for(offense),
            "message" => { "text" => offense[:message] },
            "locations" => [physical_location(offense)],
            "partialFingerprints" => partial_fingerprints_for(offense) }
        end

        def add_project_analyzer_properties(result, offense)
          return unless offense[:project_analyzer]

          result["properties"] = { "project_analyzer" => offense[:project_analyzer] }
        end

        def reporting_descriptors
          SarifRuleDescriptors.new(offenses, tool_uri: TOOL_URI).to_a
        end

        def level_for(offense)
          SarifSeverity.level_for(offense[:severity])
        end

        def partial_fingerprints_for(offense)
          { "primaryLocationLineHash" => Digest::SHA256.hexdigest(fingerprint_parts(offense).join("|")) }
        end

        def fingerprint_parts(offense)
          [offense[:cop_name], offense[:path], offense[:line], offense[:column], offense[:message]]
        end

        def physical_location(offense)
          { "physicalLocation" => {
            "artifactLocation" => artifact_location(offense),
            "region" => region_for(offense)
          } }
        end

        def artifact_location(offense)
          { "uri" => offense[:path], "uriBaseId" => ROOT_URI_BASE_ID }
        end

        def region_for(offense)
          { "startLine" => offense[:line], "startColumn" => offense[:column] }
        end

        def original_uri_base_ids
          { ROOT_URI_BASE_ID => { "uri" => "file://#{File.expand_path(Dir.pwd)}/" } }
        end

        def offenses
          @offenses ||= OffenseExtractor.offenses(@parsed)
        end
      end
    end
  end
end
