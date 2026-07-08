# frozen_string_literal: true

require "pathname"
require "rubocop"

module MetzScan
  module Commands
    class Scan
      # DDR: docs/ddrs/2026-07-08-rubocop-scope-only-config.md explains why default mode bypasses ConfigStore here.
      module ProjectConfigScope
        SCOPE_KEYS = %w[Include Exclude Includes Excludes].freeze
        ALL_COPS_PROJECT_KEYS = (SCOPE_KEYS + %w[RubyInterpreters TargetRubyVersion]).freeze
        DEFAULT_FILE = RuboCop::ConfigLoader::DEFAULT_FILE

        module_function

        def store
          ConfigStore.new
        end

        def target_ruby_version(paths)
          TargetRubyVersion.new(paths).version
        end

        # Accumulates [config_path, gem_name] pairs whenever an `inherit_gem`
        # reference can't be resolved during scope-only config loading, so
        # Runner can warn once per gem after a scan (see Next Queue item 1).
        def unresolved_inherit_gems
          @unresolved_inherit_gems ||= []
        end

        def reset_unresolved_inherit_gems!
          @unresolved_inherit_gems = []
        end

        # Default mode drops file-scope Exclude from an inherit_gem whose gem
        # isn't installed (docs/ddrs/2026-07-08-rubocop-scope-only-config.md);
        # this turns that silent degrade into a one-line stderr note per gem.
        def warn_unresolved_inherit_gems(stderr)
          unresolved_inherit_gems.uniq { |(_path, gem_name)| gem_name }.each do |(path, gem_name)|
            stderr.puts(unresolved_inherit_gem_message(path, gem_name))
          end
        end

        def unresolved_inherit_gem_message(path, gem_name)
          "metz-scan: note: #{path} inherits from gem `#{gem_name}` which is not installed; " \
            "its file-scope Exclude is not applied — install the gem or use --all-cops"
        end

        class TargetRubyVersion
          def initialize(paths, store: ConfigStore.new, loader: ConfigLoader.new)
            @paths = paths
            @store = store
            @loader = loader
          end

          def version
            config.target_ruby_version
          rescue RuboCop::Error, Psych::Exception
            nil
          end

          private

          attr_reader :paths, :store, :loader

          def config
            loaded = store.for(target_path)
            return loaded unless loaded.loaded_path == DEFAULT_FILE

            loader.default_for(target_dir)
          end

          def target_path
            Array(paths).first || RuboCop::PathUtil.pwd
          end

          def target_dir
            expanded = File.expand_path(target_path)
            File.directory?(expanded) ? expanded : File.dirname(expanded)
          end
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
          def default_for(dir)
            path = File.join(File.expand_path(dir), ".rubocop.yml")
            config = RuboCop::Config.new({}, path)
            RuboCop::ConfigLoader.merge_with_default(config, path)
          end

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
            gem_inherited_paths(raw_hash["inherit_gem"], path) + local_inherited_paths(raw_hash["inherit_from"], path)
          end

          def local_inherited_paths(inherit_from, path)
            Array(inherit_from).compact.flat_map do |entry|
              next [] if remote_config?(entry)

              inherited_path = absolute_path?(entry) ? entry : File.expand_path(entry, File.dirname(path))
              glob_path?(inherited_path) ? Dir.glob(inherited_path) : [inherited_path]
            end
          end

          def gem_inherited_paths(inherit_gem, path)
            return [] unless inherit_gem.is_a?(Hash)

            inherit_gem.flat_map { |gem_name, config_paths| paths_for_gem(gem_name, config_paths, path) }
          end

          def paths_for_gem(gem_name, config_paths, path)
            gem_dir = gem_dir_for(gem_name, path)
            return [] unless gem_dir

            Array(config_paths).map { |config_path| File.join(gem_dir, config_path) }
          end

          def gem_dir_for(gem_name, path)
            bundled_spec = bundled_specs[gem_name].first if defined?(Bundler)
            return bundled_spec.full_gem_path if bundled_spec

            Gem::Specification.find_by_name(gem_name).gem_dir
          rescue Gem::LoadError
            record_unresolved_gem(gem_name, path)
          end

          def record_unresolved_gem(gem_name, path)
            ProjectConfigScope.unresolved_inherit_gems << [path, gem_name]
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
            keys = key == "AllCops" ? ALL_COPS_PROJECT_KEYS : SCOPE_KEYS
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
