# frozen_string_literal: true

require "rubocop"

# Tiny fixture cop used exclusively by the Minitest harness self-tests for
# `Metz::Test::CopHelper`. It deliberately lives under `rubocop-metz/test/`
# (NOT under `rubocop-metz/lib/`) so it never ships in the gem and never
# registers itself globally. The cop fires on bare `puts`/`pp` sends and
# offers a trivial autocorrect (`puts X` -> `Rails.logger.info(X)`) so the
# helper's `assert_correction` macro has something to exercise.
class HelperFixtureCop < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MSG = "HelperFixtureCop: Avoid bare `puts` calls in production code."
  TARGET_METHODS = %i[puts pp].freeze

  def on_send(node)
    return unless node.receiver.nil?
    return unless TARGET_METHODS.include?(node.method_name)

    add_offense(node) do |corrector|
      args = node.arguments.map(&:source).join(", ")
      corrector.replace(node, "Rails.logger.info(#{args})")
    end
  end
  alias on_csend on_send
end
