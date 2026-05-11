# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Formatter
    # Wraps RuboCop's standard JSON formatter and enriches every offense whose
    # `cop_name` starts with `Metz/` with the metadata DSL fields published by
    # `Metz::CopMetadata`. Non-Metz offenses are passed through unchanged so the
    # top-level JSON shape and any consumer expecting standard RuboCop output
    # keeps working.
    class MetzJsonFormatter < JSONFormatter
      METZ_PREFIX = "Metz/"

      EMPTY_METADATA = {
        why_it_matters: nil,
        fix_safety: nil,
        suggested_next_moves: []
      }.freeze

      def hash_for_offense(offense)
        hash = super
        return hash unless offense.cop_name.to_s.start_with?(METZ_PREFIX)

        hash.merge!(metz_metadata_for(offense.cop_name))
      end

      private

      def metz_metadata_for(cop_name)
        cop_class = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
        return EMPTY_METADATA.dup unless cop_class.respond_to?(:metz_metadata)

        format_metadata(cop_class.metz_metadata)
      rescue StandardError
        EMPTY_METADATA.dup
      end

      def format_metadata(meta)
        {
          why_it_matters: stringify_or_nil(meta[:why_it_matters]),
          fix_safety: stringify_or_nil(meta[:fix_safety]),
          suggested_next_moves: Array(meta[:suggested_next_moves]).map(&:to_s)
        }
      end

      def stringify_or_nil(value)
        value&.to_s
      end
    end
  end
end
