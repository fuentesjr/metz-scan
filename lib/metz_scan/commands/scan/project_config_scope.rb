# frozen_string_literal: true

require "pathname"
require "rubocop"

module MetzScan
  module Commands
    class Scan
      # DDR: docs/ddrs/2026-07-08-rubocop-scope-only-config.md explains why default mode bypasses ConfigStore here.
      module ProjectConfigScope
        SCOPE_KEYS = %w[Include Exclude Includes Excludes].freeze
        ALL_COPS_SCOPE_KEYS = (SCOPE_KEYS + %w[RubyInterpreters]).freeze
        DEFAULT_FILE = RuboCop::ConfigLoader::DEFAULT_FILE

        module_function

        def store
          ConfigStore.new
        end

        class ConfigStore
          def initialize(loader: ConfigLoader.new)
            @loader = loader
            @path_cache = {}
            @object_cache = {}
          end

          def for_file(file)
            for_dir(File.dirname(file))
          end

          def for_pwd
            for_dir(RuboCop::PathUtil.pwd)
          end

          def for(file_or_dir)
            for_dir(File.directory?(file_or_dir) ? file_or_dir : File.dirname(file_or_dir))
          end

          def for_dir(dir)
            path = @path_cache[dir] ||= RuboCop::ConfigLoader.configuration_file_for(dir)
            @object_cache[path] ||= @loader.load(path)
          end
        end

        class ConfigLoader
          def load(path)
            return RuboCop::ConfigLoader.default_configuration if path == DEFAULT_FILE

            config = RuboCop::Config.new(scope_hash(path), path)
            config.deprecation_check { |_message| nil }
            config.make_excludes_absolute
            RuboCop::ConfigLoader.merge_with_default(config, path)
          end

          private

          def scope_hash(path, seen = [])
            absolute_path = File.expand_path(path)
            return {} if seen.include?(absolute_path)

            raw_hash = RuboCop::ConfigLoader.load_yaml_configuration(absolute_path)
            inherited = inherited_scope_hash(raw_hash, absolute_path, [*seen, absolute_path])
            RuboCop::ConfigLoader.merge(inherited, local_scope_hash(raw_hash))
          end

          def inherited_scope_hash(raw_hash, path, seen)
            inherited_paths(raw_hash, path).each_with_object({}) do |inherited_path, merged|
              merged.replace(RuboCop::ConfigLoader.merge(merged, scope_hash(inherited_path, seen)))
            end
          end

          def inherited_paths(raw_hash, path)
            gem_inherited_paths(raw_hash["inherit_gem"]) + local_inherited_paths(raw_hash["inherit_from"], path)
          end

          def local_inherited_paths(inherit_from, path)
            Array(inherit_from).compact.flat_map do |entry|
              next [] if remote_config?(entry)

              inherited_path = absolute_path?(entry) ? entry : File.expand_path(entry, File.dirname(path))
              glob_path?(inherited_path) ? Dir.glob(inherited_path) : [inherited_path]
            end
          end

          def gem_inherited_paths(inherit_gem)
            return [] unless inherit_gem.is_a?(Hash)

            inherit_gem.flat_map { |gem_name, config_paths| paths_for_gem(gem_name, config_paths) }
          end

          def paths_for_gem(gem_name, config_paths)
            gem_dir = gem_dir_for(gem_name)
            return [] unless gem_dir

            Array(config_paths).map { |config_path| File.join(gem_dir, config_path) }
          end

          def gem_dir_for(gem_name)
            bundled_spec = bundled_specs[gem_name].first if defined?(Bundler)
            return bundled_spec.full_gem_path if bundled_spec

            Gem::Specification.find_by_name(gem_name).gem_dir
          rescue Gem::LoadError
            nil
          end

          def bundled_specs
            Bundler.load.specs
          rescue StandardError
            {}
          end

          def local_scope_hash(raw_hash)
            raw_hash.each_with_object({}) do |(key, value), scope_hash|
              scope = scope_for(key, value)
              scope_hash[key] = scope unless scope.empty?
            end
          end

          def scope_for(key, value)
            return copy_value(value) if key == "inherit_mode" && value.is_a?(Hash)
            return {} unless value.is_a?(Hash)

            scoped_settings(key, value)
          end

          def scoped_settings(key, value)
            keys = key == "AllCops" ? ALL_COPS_SCOPE_KEYS : SCOPE_KEYS
            value.each_with_object({}) do |(setting, setting_value), scope|
              scope[setting] = copy_value(setting_value) if keys.include?(setting)
            end
          end

          def copy_value(value)
            return value.map { |item| copy_value(item) } if value.is_a?(Array)
            return value.transform_values { |item| copy_value(item) } if value.is_a?(Hash)

            value
          end

          def remote_config?(path)
            path.to_s.start_with?("http://", "https://")
          end

          def absolute_path?(path)
            Pathname.new(path.to_s).absolute?
          end

          def glob_path?(path)
            path.match?(/[*?{}\[\]]/)
          end
        end
      end
    end
  end
end
