# frozen_string_literal: true

module Metz
  # Path-based classifier for Rails-shaped source files. Used by the
  # M4 Rails-aware cops (`Metz/ControllersTooManyDirectCollaborators`,
  # `Metz/ViewsDeepNavigation`) to decide whether a file is in scope for
  # those cops. Predicates accept either a relative or an absolute path and
  # always return a strict boolean.
  #
  # The matching rules are deliberately syntactic: a path is a controller
  # iff some path segment chain ends in `app/controllers/<...>.rb`, a view
  # iff `app/views/<...>.{erb,haml,slim}`, a model iff `app/models/<...>.rb`.
  # We never touch the filesystem from here -- the inputs are already paths
  # that RuboCop or a caller has handed us.
  #
  # Phase 3 reuse: future cross-file analyzers (project index, service-soup
  # detector, repeated-branching detector) need the same path-shape question
  # answered. Keep predicates pure, allocation-light, and dependency-free
  # so they can be reused as-is from the wrapper or future analyzers.
  module FileClassifier
    CONTROLLER_PATTERN = %r{(?:\A|/)app/controllers/[^\0]+\.rb\z}
    VIEW_PATTERN       = %r{(?:\A|/)app/views/[^\0]+\.(?:erb|haml|slim)\z}
    MODEL_PATTERN      = %r{(?:\A|/)app/models/[^\0]+\.rb\z}

    module_function

    def controller?(path)
      path.to_s.match?(CONTROLLER_PATTERN)
    end

    def view?(path)
      path.to_s.match?(VIEW_PATTERN)
    end

    def model?(path)
      path.to_s.match?(MODEL_PATTERN)
    end
  end
end
