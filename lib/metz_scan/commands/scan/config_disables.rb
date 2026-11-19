# frozen_string_literal: true

require "metz_scan/commands/scan/exclude_entry_locator"

module MetzScan
  module Commands
    class Scan
      # Default `scan` strips project `Enabled` via ExecutionConfigStore, so a
      # project's `Enabled: false` would not stop a Metz cop or project
      # analyzer from reporting. Its offenses are hidden here instead, and the
      # project config that disabled it is credited in the suppression ledger.
      class ConfigDisables
        def initialize(store, rubocop_store: nil)
          @store = store
          @rubocop_store = rubocop_store
          @locators = {}
          @raw_configs = {}
        end

        def scoped_off?(path, offense)
          !disabling_config(path, offense).nil? || rubocop_disabled?(path, offense)
        end

        def record_fields(path, offense)
          entry = disabling_config(path, offense)
          return local_record_fields(entry) if entry

          remote_record_fields(rubocop_config(path))
        end

        private

        attr_reader :store, :rubocop_store

        def local_record_fields(entry)
          config_path, key = entry
          location = locator(config_path).locate_enabled(key)
          disable_record(config_path, location.line, location.reason, location.reason_status)
        end

        def remote_record_fields(config)
          disable_record(config.loaded_path, nil, nil, "unchecked")
        end

        def disable_record(config_path, line, reason, reason_status)
          { "suppressed_by" => "config_disabled", "reason" => reason,
            "reason_status" => reason_status, "directive" => nil,
            "config" => { "path" => Runner.display_path(config_path), "line" => line } }
        end

        def rubocop_disabled?(path, offense)
          return false unless rubocop_store

          config = rubocop_config(path)
          cop_name = offense.fetch("cop_name")
          config.for_cop(cop_name)["Enabled"] == false && explicit_rubocop_disable?(config, cop_name)
        end

        def explicit_rubocop_disable?(config, cop_name)
          return true unless config.for_all_cops["DisabledByDefault"]

          raw_config(config.loaded_path).to_h.dig(cop_name, "Enabled") == false
        end

        def raw_config(path)
          @raw_configs[path] ||= RuboCop::ConfigLoader.load_file(path, check: false)
        end

        def rubocop_config(path)
          rubocop_store.for_file(File.expand_path(path))
        end

        def disabling_config(path, offense)
          store.disabling_config(offense.fetch("cop_name"), File.expand_path(path))
        end

        def locator(config_path)
          @locators[config_path] ||= ExcludeEntryLocator.new(config_path)
        end
      end
    end
  end
end
