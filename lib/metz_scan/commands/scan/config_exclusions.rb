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
      # one is credited in the suppression ledger. Cops that define
      # `default_scope_file?` (the classifier-scoped rails-aware cops) keep
      # their stock classifier scope plus project Exclude in default mode
      # (owner decision 2026-10-14, question 28). Project analyzers have no cop
      # class; only a project or inherited Exclude entry scopes them off.
      class ConfigExclusions
        def initialize(store, rubocop_store: nil)
          @store = store
          @rubocop_store = rubocop_store
          @locators = {}
        end

        def scoped_off?(path, offense)
          absolute = File.expand_path(path)
          cop_class = cop_class(offense)
          return analyzer_scoped_off?(offense, absolute) unless cop_class

          cop_scoped_off?(cop_class.new(store.for_file(absolute)), absolute)
        end

        def record_fields(path, offense)
          absolute = File.expand_path(path)
          entry = applied_exclude(offense, absolute)
          return local_record_fields(entry) if entry

          remote_record_fields(offense, absolute)
        end

        private

        attr_reader :store, :rubocop_store

        def analyzer_scoped_off?(offense, absolute)
          !applied_exclude(offense, absolute).nil? || !rubocop_exclude(offense, absolute).nil?
        end

        def local_record_fields(entry)
          location = locator(entry.config_path).locate(entry.key, entry.pattern)
          exclude_record(location.reason, location.reason_status, config(entry, location))
        end

        def remote_record_fields(offense, absolute)
          config_obj, pattern = rubocop_exclude(offense, absolute)
          return unless pattern

          exclude_record(nil, "unchecked", remote_config(config_obj, pattern))
        end

        def exclude_record(reason, reason_status, config_hash)
          { "suppressed_by" => "config_exclude", "reason" => reason,
            "reason_status" => reason_status, "directive" => nil, "config" => config_hash }
        end

        def remote_config(config_obj, pattern)
          { "path" => Runner.display_path(config_obj.loaded_path), "line" => nil, "pattern" => display(pattern) }
        end

        def rubocop_exclude(offense, absolute)
          return unless rubocop_store

          config_obj = rubocop_store.for_file(absolute)
          badge = RuboCop::Cop::Badge.parse(offense.fetch("cop_name"))
          pattern = matching_exclude(config_obj, badge, absolute)
          [config_obj, pattern] if pattern
        end

        def matching_exclude(config_obj, badge, absolute)
          relative = config_obj.path_relative_to_config(absolute)
          Array(config_obj.for_badge(badge)["Exclude"]).find do |pattern|
            RuboCop::PathUtil.match_path?(pattern, relative) || RuboCop::PathUtil.match_path?(pattern, absolute)
          end
        end

        def cop_scoped_off?(cop, file)
          return !cop.default_scope_file?(file) if cop.respond_to?(:default_scope_file?)

          cop.excluded_file?(file)
        end

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
