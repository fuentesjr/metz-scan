# frozen_string_literal: true

require "rubocop"

require "metz_scan/commands/scan/exclude_entry_locator"

module MetzScan
  module Commands
    class Scan
      # Default mode runs stock Metz config (--force-default-config) but must
      # still honor the project's per-cop file scope (Include/Exclude), the
      # same way #33 honors AllCops: Exclude. RuboCop's own excluded_file?
      # resolves the project config's scope per cop (#37); offenses on files a
      # cop is scoped off are hidden, and the project Exclude entry that hid
      # one is credited in the suppression ledger. Project analyzers have no
      # cop class; only a project Exclude entry scopes them off.
      class ConfigExclusions
        def initialize(store)
          @store = store
          @locators = {}
        end

        def scoped_off?(path, offense)
          absolute = File.expand_path(path)
          cop_class = cop_class(offense)
          return !applied_exclude(offense, absolute).nil? unless cop_class

          cop_class.new(store.for_file(absolute)).excluded_file?(absolute)
        end

        def record_fields(path, offense)
          entry = applied_exclude(offense, File.expand_path(path))
          return unless entry

          location = locator(entry.config_path).locate(entry.key, entry.pattern)
          { "suppressed_by" => "config_exclude", "reason" => location.reason,
            "reason_status" => location.reason_status, "directive" => nil, "config" => config(entry, location) }
        end

        private

        attr_reader :store

        def applied_exclude(offense, file)
          store.applied_exclude(RuboCop::Cop::Badge.parse(offense.fetch("cop_name")), file)
        end

        def cop_class(offense)
          RuboCop::Cop::Registry.global.find_by_cop_name(offense.fetch("cop_name"))
        end

        def config(entry, location)
          { "path" => Runner.display_path(entry.config_path), "line" => location.line,
            "pattern" => display(entry.pattern) }
        end

        def display(pattern)
          pattern.is_a?(Regexp) ? pattern.inspect : pattern
        end

        def locator(config_path)
          @locators[config_path] ||= ExcludeEntryLocator.new(config_path)
        end
      end
    end
  end
end
