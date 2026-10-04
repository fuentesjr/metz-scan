# frozen_string_literal: true

require "rubocop"

require "metz_scan/commands/scan/exclude_entries"

module MetzScan
  module Commands
    class Scan
      module ProjectConfigScope
        # Remembers which config file wrote each Exclude entry the scope-only
        # loader reads, so the suppression ledger can credit the entry a cop
        # actually applies. Raw YAML entries are tracked by object identity:
        # two files writing the same pattern stay distinct. A cop's or
        # department's `Enabled` is stamped with its file instead (see
        # ENABLED_SOURCE).
        class ExcludeProvenance
          def initialize
            @sources = {}.compare_by_identity
            @entries = {}
          end

          def load_yaml_configuration(absolute_path)
            RuboCop::ConfigLoader.load_yaml_configuration(absolute_path).tap do |raw_hash|
              record_sources(raw_hash, absolute_path)
            end
          end

          def make_excludes_absolute(config)
            raw_patterns = ExcludeEntries.patterns(config)
            config.make_excludes_absolute
            @entries[config.loaded_path] = ExcludeEntries.new(raw_patterns, ExcludeEntries.patterns(config), @sources)
          end

          def entries_for(config)
            @entries.fetch(config.loaded_path) { ExcludeEntries.new }
          end

          private

          def record_sources(raw_hash, absolute_path)
            raw_hash.each_value do |value|
              next unless value.is_a?(Hash)

              Array(value["Exclude"]).each { |entry| @sources[entry] = absolute_path }
              value[ENABLED_SOURCE] = absolute_path if value.key?("Enabled")
            end
          end
        end
      end
    end
  end
end
