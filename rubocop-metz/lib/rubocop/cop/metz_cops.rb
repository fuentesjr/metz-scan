# frozen_string_literal: true

# Central require point for every Metz cop. M2+ adds one
# `require_relative "metz/<cop_name>"` line per cop, keeping the registry
# wiring in a single discoverable location.

require_relative "metz/classes_too_long"
require_relative "metz/methods_too_long"
require_relative "metz/methods_too_many_parameters"
require_relative "metz/demeter_train_wreck"
