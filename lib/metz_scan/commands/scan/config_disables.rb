# frozen_string_literal: true

require "metz_scan/commands/scan/exclude_entry_locator"

module MetzScan
  module Commands
    class Scan
      # Default mode runs stock Metz config (--force-default-config), so a
      # project's `Enabled: false` would not stop a Metz cop or project
      # analyzer from reporting. Its offenses are hidden here instead, and the
      # project config that disabled it is credited in the suppression ledger.
      class ConfigDisables
        def initialize(store)
          @store = store
          @locators = {}
        end

        def scoped_off?(path, offense)
          !disabling_config(path, offense).nil?
        end

        def record_fields(path, offense)
          config_path, key = disabling_config(path, offense)
          location = locator(config_path).locate_enabled(key)
          { "suppressed_by" => "config_disabled", "reason" => location.reason,
            "reason_status" => location.reason_status, "directive" => nil,
            "config" => { "path" => Runner.display_path(config_path), "line" => location.line } }
        end

        private

        attr_reader :store

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
