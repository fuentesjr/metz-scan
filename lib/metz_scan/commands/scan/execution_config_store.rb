# frozen_string_literal: true

require "rubocop"

require "metz_scan/commands/scan/project_config_scope"

module MetzScan
  module Commands
    class Scan
      # Execution-layer ConfigStore for default mode. Keeps AllCops scope and
      # per-cop Include/inherit_mode from the project config. Default `scan`
      # strips project Enabled and per-cop Exclude so RuboCop runs with stock
      # Metz defaults and SuppressionLedger can record project suppressions;
      # `honor_suppressions: true` (--auto-fix) keeps per-cop Exclude and
      # Enabled: false while never enabling opt-in cops.
      class ExecutionConfigStore
        COP_EXECUTION_KEYS = %w[Include Includes inherit_mode].freeze
        TOP_LEVEL_KEYS = %w[AllCops inherit_mode].freeze

        def initialize(scope_store = ProjectConfigScope.store, honor_suppressions: false)
          @scope_store = scope_store
          @honor_suppressions = honor_suppressions
          @cache = {}
        end

        def for_file(file) = for_dir(File.dirname(file))

        def for_pwd = for_dir(RuboCop::PathUtil.pwd)

        def for(file_or_dir)
          for_dir(File.directory?(file_or_dir) ? file_or_dir : File.dirname(file_or_dir))
        end

        def for_dir(dir)
          scope_config = scope_store.for_dir(dir)
          @cache[scope_config.loaded_path] ||= build_config(scope_config)
        end

        private

        attr_reader :scope_store

        def build_config(scope_config)
          path = scope_config.loaded_path
          return ProjectConfigScope.ensure_metz_defaults_loaded if path == ProjectConfigScope::DEFAULT_FILE

          defaults = ProjectConfigScope.ensure_metz_defaults_loaded
          merged_config(execution_hash(scope_config, defaults), path)
        end

        def merged_config(hash, path)
          config = RuboCop::Config.new(hash, path)
          config.deprecation_check { |_message| nil }
          config.make_excludes_absolute
          RuboCop::ConfigLoader.merge_with_default(config, path)
        end

        def execution_hash(scope_config, defaults)
          hash = top_level_entries(scope_config)
          scope_config.each_key { |key| assign_cop_entry(hash, key, scope_config, defaults) }
          hash
        end

        def cop_hash?(key, value) = !top_level_key?(key) && value.is_a?(Hash)

        def assign_cop_entry(hash, key, scope_config, defaults)
          value = scope_config[key]
          return unless cop_hash?(key, value)

          entry = cop_entry(scope_config, defaults, key, value)
          hash[key] = entry unless entry.empty?
        end

        def top_level_entries(scope_config)
          all_cops = slice_keys(scope_config["AllCops"], ProjectConfigScope::ALL_COPS_PROJECT_KEYS)
          {}.tap do |hash|
            hash["inherit_mode"] = copy_value(scope_config["inherit_mode"]) if scope_config["inherit_mode"].is_a?(Hash)
            hash["AllCops"] = all_cops unless all_cops.empty?
          end
        end

        def top_level_key?(key) = TOP_LEVEL_KEYS.include?(key)

        def cop_entry(scope_config, defaults, key, value)
          entry = slice_keys(value, COP_EXECUTION_KEYS)
          return apply_suppressions(scope_config, defaults, key, entry) if @honor_suppressions
          return entry unless clear_stock_exclude?(scope_config, defaults, key, value)

          entry.merge("Exclude" => [], "inherit_mode" => override_exclude_mode(entry["inherit_mode"]))
        end

        def apply_suppressions(scope_config, defaults, key, entry)
          value = scope_config[key]
          entry = entry.merge("Exclude" => copy_value(value["Exclude"])) if value.key?("Exclude")
          enabled = suppressed_enabled(scope_config, defaults, key, value)
          enabled.nil? ? entry : entry.merge("Enabled" => enabled)
        end

        def suppressed_enabled(scope_config, defaults, key, value)
          return false if value["Enabled"] == false || scope_config.for_cop(key)["Enabled"] == false

          true if reenabled_default_cop?(scope_config, defaults, key, value)
        end

        def reenabled_default_cop?(scope_config, defaults, key, value)
          defaults.dig(key, "Enabled") == true &&
            value[ProjectConfigScope::ENABLED_SOURCE] &&
            scope_config.for_cop(key)["Enabled"] == true
        end

        def clear_stock_exclude?(scope_config, defaults, key, value)
          stock_exclude_dropped?(defaults, key, value) || scope_store.project_exclude?(scope_config, key)
        end

        def slice_keys(hash, keys)
          return {} unless hash.is_a?(Hash)

          hash.slice(*keys).transform_values { |item| copy_value(item) }
        end

        def stock_exclude_dropped?(defaults, key, value)
          stock = Array(defaults.dig(key, "Exclude"))
          stock.any? && !(stock - Array(value["Exclude"])).empty?
        end

        def override_exclude_mode(mode)
          updated = mode ? copy_value(mode) : {}
          updated["merge"] = Array(updated["merge"]) - ["Exclude"] if updated.key?("merge")
          updated["override"] = Array(updated["override"]) | ["Exclude"]
          updated
        end

        def copy_value(value)
          return value.map { |item| copy_value(item) } if value.is_a?(Array)
          return value.transform_values { |item| copy_value(item) } if value.is_a?(Hash)

          value
        end
      end
    end
  end
end
