# frozen_string_literal: true

require "yaml"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class TargetSet
        DEFAULT_SCAN_CHILDREN = %w[app lib].freeze

        def initialize(paths:, default_apps_path:, targets_file: nil)
          @paths = Array(paths)
          @default_apps_path = default_apps_path
          @targets_file = targets_file && File.expand_path(targets_file)
          reject_mixed_target_inputs!
        end

        attr_reader :targets_file

        def paths = raw_targets.map { |path| File.expand_path(path) }.uniq.sort

        def ensure_present!
          missing = paths.reject { |path| File.exist?(path) }
          raise Error, "calibration target missing: #{missing.first}" unless missing.empty?

          missing_scan_path = manifest_scan_paths.flatten.find { |path| !File.directory?(path) }
          raise Error, "calibration scan path missing: #{missing_scan_path}" if missing_scan_path
        end

        def scan_paths_for(target)
          manifest_paths = manifest_scan_paths_by_target[File.expand_path(target)]
          return manifest_paths if manifest_paths

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
          return manifest_target_roots if targets_file

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

        def reject_mixed_target_inputs!
          return unless targets_file && explicit_targets?

          raise Error, "cannot combine --targets-file with explicit PATH targets"
        end

        def manifest_target_roots
          manifest_entries.map { |entry| entry.fetch("root") }
        end

        def manifest_scan_paths_by_target
          return {} unless targets_file

          @manifest_scan_paths_by_target ||= manifest_entries.to_h do |entry|
            root = File.expand_path(entry.fetch("root"))
            [root, Array(entry.fetch("scan_paths")).map { |path| File.expand_path(path, root) }]
          end
        end

        def manifest_scan_paths
          return [] unless targets_file

          manifest_scan_paths_by_target.values
        end

        def manifest_entries
          @manifest_entries ||= parse_manifest_entries
        end

        def parse_manifest_entries
          target_entries.map { |entry| normalize_manifest_entry(entry) }
        rescue Psych::Exception => e
          raise Error, "invalid calibration targets file: #{e.message}"
        end

        def target_entries
          manifest_document.fetch("targets").tap do |entries|
            raise Error, "calibration targets file must contain a targets list" unless entries.is_a?(Array)
          end
        rescue KeyError
          raise Error, "calibration targets file must contain a targets list"
        end

        def manifest_document
          raise Error, "calibration targets file missing: #{targets_file}" unless File.file?(targets_file)

          YAML.safe_load_file(targets_file, aliases: false) || {}
        end

        def normalize_manifest_entry(entry)
          raise Error, "calibration target entry must be a mapping" unless entry.is_a?(Hash)

          { "root" => manifest_entry_root(entry), "scan_paths" => manifest_entry_scan_paths(entry) }
        end

        def manifest_entry_root(entry)
          entry.fetch("root") { raise Error, "calibration target entry missing root" }.to_s
        end

        def manifest_entry_scan_paths(entry)
          scan_paths = entry.fetch("scan_paths") { raise Error, "calibration target entry missing scan_paths" }
          raise Error, "calibration target scan_paths must be a list" unless scan_paths.is_a?(Array)
          raise Error, "calibration target scan_paths must not be empty" if scan_paths.empty?

          scan_paths.map(&:to_s)
        end
      end
    end
  end
end
