# frozen_string_literal: true

require "metz_scan/commands/scan/project_config_scope"

module MetzScan
  module Commands
    class Scan
      module TargetRubyVersion
        ENV_KEY = "RUBOCOP_TARGET_RUBY_VERSION"

        module_function

        def with_project_config(paths, all_cops:, &)
          return yield if all_cops

          EnvOverride.new(ProjectConfigScope.target_ruby_version(paths)).with_env(&)
        end

        class EnvOverride
          def initialize(value)
            @value = value
          end

          def with_env(&)
            return yield unless value

            with_override(&)
          end

          private

          attr_reader :value

          def with_override
            preserve
            ENV[ENV_KEY] = value.to_s
            yield
          ensure
            restore
          end

          def preserve
            @had_value = ENV.key?(ENV_KEY)
            @previous = ENV.fetch(ENV_KEY, nil)
          end

          def restore
            return ENV[ENV_KEY] = @previous if @had_value

            ENV.delete(ENV_KEY)
          end
        end
      end
    end
  end
end
