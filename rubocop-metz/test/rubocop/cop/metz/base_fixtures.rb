# frozen_string_literal: true

# Named test cops for the `RuboCop::Cop::Metz::Base` Minitest specs.
# Anonymous subclasses of `RuboCop::Cop::Base` cannot be enrolled in the
# RuboCop global registry (the badge generator dereferences `name.split`),
# so the harness exercises behaviour through these top-level named classes
# instead. Mirrors the pattern used by `HelperFixtureCop`.

require "rubocop"
require "rubocop-metz"

class MetzBaseTestCopOnSend < RuboCop::Cop::Metz::Base
  def on_send(node); end
end

class MetzBaseTestCopMetadata < RuboCop::Cop::Metz::Base
  why_it_matters "matters"
  fix_safety :unsafe
  suggested_next_moves ["extract method"]
end

class MetzBaseTestCopDefaults < RuboCop::Cop::Metz::Base
end
