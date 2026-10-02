# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Commands
    class Scan
      module ProjectConfigScope
        # The per-cop Exclude entries a scope-only config applies, each mapped
        # back to the config file that wrote it. Entries are paired with their
        # source by object identity before make_excludes_absolute rewrites
        # them, so an entry a derived file overrides is never credited.
        class ExcludeEntries
          Entry = Struct.new(:config_path, :key, :pattern, keyword_init: true)

          def self.patterns(config)
            config.to_h.filter_map { |key, value| [key, value["Exclude"].dup] if per_cop_exclude?(key, value) }.to_h
          end

          def self.per_cop_exclude?(key, value)
            key != "AllCops" && value.is_a?(Hash) && value["Exclude"].is_a?(Array)
          end

          def initialize(raw_patterns = {}, absolute_patterns = {}, sources = {})
            @entries = {}
            raw_patterns.each do |key, patterns|
              patterns.zip(absolute_patterns.fetch(key)).each { |raw, absolute| index(key, raw, absolute, sources) }
            end
          end

          # The first Exclude pattern a cop applies to `file` that a project
          # config wrote; stock-default patterns have no source and are skipped.
          def applied(config, badge, file)
            relative = config.path_relative_to_config(file)
            Array(config.for_badge(badge)["Exclude"]).lazy.filter_map do |pattern|
              sourced_entry(badge, pattern) if matches?(pattern, relative, file)
            end.first
          end

          private

          def index(key, raw, absolute, sources)
            return unless sources.key?(raw)

            @entries[[key, absolute]] = Entry.new(config_path: sources.fetch(raw), key: key, pattern: raw)
          end

          def sourced_entry(badge, pattern)
            @entries[[badge.to_s, pattern]] || @entries[[badge.department_name, pattern]]
          end

          def matches?(pattern, relative, file)
            RuboCop::PathUtil.match_path?(pattern, relative) || RuboCop::PathUtil.match_path?(pattern, file)
          end
        end
      end
    end
  end
end
