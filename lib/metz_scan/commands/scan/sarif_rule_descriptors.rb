# frozen_string_literal: true

require_relative "offense_extractor"
require_relative "sarif_severity"

module MetzScan
  module Commands
    class Scan
      class SarifRuleDescriptors
        def initialize(offenses, tool_uri:)
          @offenses = offenses
          @tool_uri = tool_uri
        end

        def to_a
          offenses_by_cop.map { |cop_name, offenses| descriptor_for(cop_name, offenses) }
        end

        private

        attr_reader :offenses, :tool_uri

        def descriptor_for(cop_name, offenses)
          add_optional_texts(base_descriptor(cop_name, offenses), cop_name)
        end

        def base_descriptor(cop_name, offenses)
          { "id" => cop_name, "name" => cop_name,
            "shortDescription" => { "text" => offenses.first[:message].to_s },
            "defaultConfiguration" => { "level" => descriptor_level(offenses) },
            "helpUri" => "#{tool_uri}#rule-#{cop_name}" }
        end

        def add_optional_texts(descriptor, cop_name)
          text = rule_why_text(cop_name)
          add_text(add_text(descriptor, "help", text), "fullDescription", text)
        end

        def add_text(descriptor, key, text)
          return descriptor if text.to_s.empty?

          descriptor.merge(key => { "text" => text })
        end

        def descriptor_level(offenses)
          SarifSeverity.highest_level(offenses.map { |offense| offense[:severity] })
        end

        def rule_why_text(cop_name)
          first = offense_for(cop_name)
          first&.fetch(:why_it_matters) { OffenseExtractor.registry_why_it_matters(cop_name) }
        end

        def offense_for(cop_name)
          offenses_by_cop.fetch(cop_name, []).first
        end

        def offenses_by_cop
          @offenses_by_cop ||= offenses.group_by { |offense| offense[:cop_name] }
        end
      end
    end
  end
end
