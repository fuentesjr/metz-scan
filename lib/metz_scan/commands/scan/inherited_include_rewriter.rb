# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Commands
    class Scan
      module ProjectConfigScope
        # Mirrors RuboCop::ConfigLoaderResolver#fix_include_paths for
        # scope-only config inheritance across `.rubocop*` files.
        module InheritedIncludeRewriter
          module_function

          def rewrite(hash, from_path, to_path)
            return hash unless File.basename(from_path).start_with?(".rubocop")
            return hash if File.dirname(from_path) == File.dirname(to_path)

            base_dir = File.dirname(from_path)
            derived_dir = File.dirname(to_path)
            hash.transform_values { |value| rewrite_value(value, base_dir, derived_dir) }
          end

          def rewrite_value(value, base_dir, derived_dir)
            return value unless value.is_a?(Hash) && value["Include"]

            rewritten = Array(value["Include"]).map { |pattern| rewrite_pattern(pattern, base_dir, derived_dir) }
            value.merge("Include" => rewritten)
          end

          def rewrite_pattern(pattern, base_dir, derived_dir)
            return pattern unless relative_anchored?(pattern)

            RuboCop::PathUtil.relative_path(File.join(base_dir, pattern), derived_dir)
          end

          def relative_anchored?(pattern)
            pattern.is_a?(String) && !Pathname.new(pattern).absolute? && !pattern.start_with?("**/")
          end
        end
      end
    end
  end
end
