# frozen_string_literal: true

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class TargetSet
        DEFAULT_SCAN_CHILDREN = %w[app lib].freeze

        def initialize(paths:, default_apps_path:)
          @paths = Array(paths)
          @default_apps_path = default_apps_path
        end

        def paths = raw_targets.map { |path| File.expand_path(path) }.uniq.sort

        def ensure_present!
          missing = paths.reject { |path| File.exist?(path) }
          raise Error, "calibration target missing: #{missing.first}" unless missing.empty?
        end

        def scan_paths_for(target)
          scan_paths = scan_children_for(target)
          scan_paths = [target] if scan_paths.empty? && explicit_targets?
          scan_paths.map { |path| File.expand_path(path) }
        end

        private

        attr_reader :default_apps_path

        def explicit_targets?
          !@paths.empty?
        end

        def raw_targets
          @paths.empty? ? discovered_default_targets : @paths
        end

        def discovered_default_targets
          return [default_apps_path] unless File.directory?(default_apps_path)

          default_target_children.empty? ? [default_apps_path] : default_target_children
        end

        def default_target_children
          Dir.children(default_apps_path)
             .map { |child| File.join(default_apps_path, child) }
             .select { |path| File.directory?(path) }
        end

        def scan_children_for(target)
          DEFAULT_SCAN_CHILDREN.map { |child| File.join(target, child) }
                               .select { |path| File.directory?(path) }
        end
      end
    end
  end
end
