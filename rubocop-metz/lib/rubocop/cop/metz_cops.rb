# frozen_string_literal: true

# Central require point for every Metz cop. Keep one
# `require_relative "metz/<cop_name>"` line per cop so registry wiring stays in
# a single discoverable location.

require_relative "metz/classes_too_long"
require_relative "metz/methods_too_long"
require_relative "metz/methods_too_many_parameters"
require_relative "metz/demeter_train_wreck"
require_relative "metz/controllers_too_many_direct_collaborators"
require_relative "metz/test_asserts_on_internals"
require_relative "metz/test_reaches_private"
require_relative "metz/views_deep_navigation"
