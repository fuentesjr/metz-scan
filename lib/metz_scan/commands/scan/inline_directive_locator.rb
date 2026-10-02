# frozen_string_literal: true

require "rubocop"

module MetzScan
  module Commands
    class Scan
      # Credits a suppressed offense to the innermost real directive comment
      # covering it. Ranges RuboCop opens at -Infinity for opt-in cops are
      # synthetic (CommentConfig::ConfigDisabledCopDirectiveComment), not a
      # comment anyone wrote, so they credit nothing.
      class InlineDirectiveLocator
        def initialize
          @ranges = {}
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
          location = offense.fetch("location")
          ranges_for(path).fetch(offense.fetch("cop_name"), [])
                          .select { |range| covers?(range, location) }
                          .max_by(&:begin)&.directive
        end

        def covers?(range, location)
          range.is_a?(RuboCop::CommentConfig::DirectiveRange) && range.begin.finite? &&
            range.end >= location.fetch("start_line") && range.begin <= location.fetch("last_line")
        end

        def ranges_for(path)
          @ranges[path] ||= processed_source(path).comment_config.cop_disabled_line_ranges
        end

        def processed_source(path)
          config = RuboCop::ConfigLoader.default_configuration
          RuboCop::ProcessedSource.from_file(path, config.target_ruby_version, parser_engine: config.parser_engine)
                                  .tap { |source| source.config = config }
                                  .tap { |source| source.registry = RuboCop::Cop::Registry.global }
        end
      end
    end
  end
end
