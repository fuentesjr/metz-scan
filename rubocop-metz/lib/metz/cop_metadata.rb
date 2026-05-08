# frozen_string_literal: true

module Metz
  # Metadata DSL for Metz cops. Provides class-level setter/reader macros for
  # `why_it_matters`, `fix_safety`, and `suggested_next_moves`. Works whether
  # `include`d (instance-style sub-modules) or `extend`ed onto the class.
  #
  # Public contract for a cop class that never invokes any setter:
  #   - why_it_matters         -> ""        (empty string)
  #   - fix_safety             -> :manual   (the safest, no-autocorrect tier)
  #   - suggested_next_moves   -> []        (empty, frozen array)
  module CopMetadata
    UNSET = Object.new.freeze
    private_constant :UNSET

    DEFAULT_WHY_IT_MATTERS = ""
    DEFAULT_FIX_SAFETY = :manual
    DEFAULT_SUGGESTED_NEXT_MOVES = [].freeze

    def self.included(base)
      base.extend(self)
    end

    def why_it_matters(value = UNSET)
      return @metz_why_it_matters = value unless UNSET.equal?(value)

      defined?(@metz_why_it_matters) ? @metz_why_it_matters : DEFAULT_WHY_IT_MATTERS
    end

    def fix_safety(value = UNSET)
      return @metz_fix_safety = value unless UNSET.equal?(value)

      defined?(@metz_fix_safety) ? @metz_fix_safety : DEFAULT_FIX_SAFETY
    end

    def suggested_next_moves(value = UNSET)
      return @metz_suggested_next_moves = value unless UNSET.equal?(value)

      defined?(@metz_suggested_next_moves) ? @metz_suggested_next_moves : DEFAULT_SUGGESTED_NEXT_MOVES
    end

    def metz_metadata
      {
        why_it_matters: why_it_matters,
        fix_safety: fix_safety,
        suggested_next_moves: suggested_next_moves
      }
    end
  end
end
