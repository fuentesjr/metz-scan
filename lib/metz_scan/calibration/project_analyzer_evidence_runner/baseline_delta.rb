# frozen_string_literal: true

require "json"
require "yaml"

module MetzScan
  module Calibration
    module ProjectAnalyzerEvidenceRunner
      class BaselineDelta
        COUNT_KEYS = %w[finding_count offense_count].freeze
        private_constant :COUNT_KEYS

        def initialize(summary:, baseline_file:)
          @summary = summary
          @baseline = BaselineFile.load(baseline_file)
        end

        def to_h
          validate_scope!
          delta_payload
        end

        private

        attr_reader :summary, :baseline

        def delta_payload
          { "baseline" => baseline.identity,
            "finding_count" => metric_delta("finding_count", current_summary, baseline_summary),
            "offense_count" => metric_delta("offense_count", current_summary, baseline_summary),
            "rules" => rule_deltas,
            "breakdowns" => breakdown_deltas }.compact
        end

        def validate_scope!
          BaselineFile.scope_keys.each { |key| validate_scope_value!(key) if baseline_scope.key?(key) }
        end

        def validate_scope_value!(key)
          return if normalized_scope_value(key, baseline_scope[key]) == normalized_scope_value(key, summary[key])

          raise Error, "baseline scope mismatch for #{key}: expected #{baseline_scope[key].inspect}, " \
                       "got #{summary[key].inspect}"
        end

        def normalized_scope_value(key, value)
          case key
          when "targets_file" then value && File.expand_path(value.to_s)
          when "analyzer_filter" then Array(value).map(&:to_s).sort
          else value
          end
        end

        def rule_deltas
          all_rule_names.map { |name| rule_delta_for(name) }
        end

        def rule_delta_for(name)
          { "cop_name" => name,
            "finding_count" => rule_metric_delta(name, "finding_count"),
            "offense_count" => rule_metric_delta(name, "offense_count") }
        end

        def rule_metric_delta(name, key)
          metric_delta(key, current_rules.fetch(name, {}), baseline_rules.fetch(name, {}))
        end

        def all_rule_names
          (current_rules.keys | baseline_rules.keys).sort
        end

        def current_rules
          @current_rules ||= rules_by_name(current_summary)
        end

        def baseline_rules
          @baseline_rules ||= rules_by_name(baseline_summary)
        end

        def rules_by_name(source)
          Array(rules_for(source)).to_h { |rule| [rule.fetch("cop_name"), rule] }
        end

        def rules_for(source)
          BaselineFile.rules_for(source)
        end

        def breakdown_deltas
          { "confidence" => breakdown_delta_for("confidence"),
            "triage_severity" => breakdown_delta_for("triage_severity"),
            "metadata" => metadata_breakdown_deltas }.compact
        end

        def metadata_breakdown_deltas
          category_deltas = breakdown_delta_for("project_analyzer_category", metadata: true)
          { "project_analyzer_category" => category_deltas } unless category_deltas.empty?
        end

        def breakdown_delta_for(key, metadata: false)
          current = breakdown_counts(current_summary, key, metadata: metadata)
          baseline = breakdown_counts(baseline_summary, key, metadata: metadata)

          (current.keys | baseline.keys).sort.map do |value|
            { "value" => value, "finding_count" => count_delta(current.fetch(value, 0), baseline.fetch(value, 0)) }
          end
        end

        def breakdown_counts(source, key, metadata:)
          values = metadata ? source.dig("breakdowns", "metadata", key) : source.dig("breakdowns", key)
          Array(values).to_h { |entry| [entry.fetch("value"), entry.fetch("finding_count").to_i] }
        end

        def metric_delta(key, current, baseline)
          count_delta(current.fetch(key, 0), baseline.fetch(key, 0))
        end

        def count_delta(current, baseline)
          current = current.to_i
          baseline = baseline.to_i
          { "baseline" => baseline, "current" => current, "delta" => current - baseline }
        end

        def current_summary = summary

        def baseline_summary
          baseline.summary
        end

        def baseline_scope
          baseline.scope
        end
      end

      class BaselineFile
        SCOPE_KEYS = %w[targets_file default_output analyzer_filter].freeze
        private_constant :SCOPE_KEYS

        def self.load(path)
          new(path: path)
        end

        def self.from_summary(summary, label:, generated_from:, targets_file: nil)
          document = document_for(summary, label: label, generated_from: generated_from, targets_file: targets_file)
          new(document: document)
        end

        def self.scope_keys = SCOPE_KEYS

        def self.rules_for(source)
          source["rules"] || source.dig("project_analyzers", "rules") || []
        end

        def initialize(path: nil, document: nil)
          @path = path && File.expand_path(path)
          @document = document
        end

        attr_reader :path

        def identity
          { "file" => path, "label" => document["label"], "generated_from" => document["generated_from"] }.compact
        end

        def to_h
          document
        end

        def to_yaml
          YAML.dump(to_h)
        end

        def summary
          document.fetch("summary", document)
        end

        def scope
          document.fetch("scope", {})
        end

        class << self
          private

          def document_for(summary, label:, generated_from:, targets_file:)
            { "label" => label, "generated_from" => generated_from,
              "scope" => scope_for(summary, targets_file: targets_file),
              "summary" => compact_summary_for(summary) }
          end

          def scope_for(summary, targets_file:)
            { "targets_file" => targets_file || summary["targets_file"],
              "default_output" => summary.fetch("default_output"),
              "analyzer_filter" => summary.fetch("analyzer_filter", []) }
          end

          def compact_summary_for(summary)
            { "finding_count" => summary.fetch("finding_count"),
              "offense_count" => summary.fetch("offense_count"),
              "rules" => compact_rules_for(summary),
              "breakdowns" => summary.fetch("breakdowns", {}) }
          end

          def compact_rules_for(summary)
            rules_for(summary).map { |rule| compact_rule_for(rule) }
          end

          def compact_rule_for(rule)
            { "cop_name" => rule.fetch("cop_name"),
              "finding_count" => rule.fetch("finding_count"),
              "offense_count" => rule.fetch("offense_count") }
          end
        end

        private

        def document
          @document ||= load_document
        end

        def load_document
          JSON.parse(contents)
        rescue JSON::ParserError
          YAML.safe_load(contents, aliases: false)
        end

        def contents
          @contents ||= File.read(path)
        end
      end
    end
  end
end
