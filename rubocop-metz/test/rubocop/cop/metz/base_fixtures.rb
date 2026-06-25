# frozen_string_literal: true

# Named test cop for the `RuboCop::Cop::Metz::Base` compatibility shim.

require "rubocop"
require "rubocop-metz"

class MetzBaseCompatibilityTestCop < RuboCop::Cop::Metz::Base
  why_it_matters "compatibility matters"
  fix_safety :unsafe
  suggested_next_moves ["keep downstream custom cops working"]

  def on_send(node); end
end
