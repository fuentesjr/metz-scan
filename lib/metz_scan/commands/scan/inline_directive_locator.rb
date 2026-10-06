# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Commands
    class Scan
      # Credits a suppressed offense to the innermost real directive comment
      # covering it. Ranges RuboCop opens at -Infinity for opt-in cops are
      # synthetic (CommentConfig::ConfigDisabledCopDirectiveComment), not a
      # comment anyone wrote, so they credit nothing.
      #
      # Project analyzers are not RuboCop cops, so `# rubocop:disable` does not
      # reach them; their directive is `# metz-scan:disable`. Their ranges come
      # from RuboCop's own directive parser run over a copy of the source in
      # which only metz-scan markers read as rubocop ones; of RuboCop's
      # directive modes, only `disable` counts for them.
      class InlineDirectiveLocator
        ANALYZER_PREFIX = "MetzProject/"
        MARKER = /#\s*\K(?:rubocop|metz-scan)(?=\s*:)/
        ANALYZER_MARKERS = { "rubocop" => "rubocop-ignored", "metz-scan" => "rubocop" }.freeze

        def initialize
          @ranges = {}
        end

        # Index-backed findings can point at a constant with no source file
        # (an external root), which holds no directive.
        def analyzer_disabled?(path, offense)
          analyzer?(offense) && File.file?(path) && !covering_directive(path, offense).nil?
        end

        def record_fields(path, offense)
          directive = covering_directive(path, offense)
          return unless directive

          reason = directive.reason
          { "suppressed_by" => "inline_disable", "reason" => reason, "reason_status" => reason ? "present" : "missing",
            "directive" => { "line" => directive.line_number }, "config" => nil }
        end

        private

        def covering_directive(path, offense)
          analyzer = analyzer?(offense)
          ranges_for(path, analyzer).fetch(offense.fetch("cop_name"), [])
                                    .select { |range| covers?(range, offense.fetch("location"), analyzer) }
                                    .max_by(&:begin)&.directive
        end

        def covers?(range, location, analyzer)
          range.is_a?(RuboCop::CommentConfig::DirectiveRange) && range.begin.finite? &&
            (!analyzer || range.directive.mode == "disable") &&
            range.end >= location.fetch("start_line") && range.begin <= location.fetch("last_line")
        end

        def analyzer?(offense)
          offense.fetch("cop_name").start_with?(ANALYZER_PREFIX)
        end

        def ranges_for(path, analyzer)
          @ranges[[path, analyzer]] ||= processed_source(path, analyzer).comment_config.cop_disabled_line_ranges
        end

        def processed_source(path, analyzer)
          config = RuboCop::ConfigLoader.default_configuration
          RuboCop::ProcessedSource.new(source(path, analyzer), config.target_ruby_version, path,
                                       parser_engine: config.parser_engine)
                                  .tap { |processed| processed.config = config }
                                  .tap { |processed| processed.registry = RuboCop::Cop::Registry.global }
        end

        def source(path, analyzer)
          text = File.read(path, mode: "rb")
          analyzer ? text.gsub(MARKER, ANALYZER_MARKERS) : text
        end
      end
    end
  end
end
