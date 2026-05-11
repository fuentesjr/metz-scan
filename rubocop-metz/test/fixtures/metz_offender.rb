# frozen_string_literal: true

# Canonical fixture that intentionally fires a `Metz/*` cop so the
# MetzJsonFormatter can be exercised against real RuboCop output. The body of
# `too_long_method` exceeds the default `Metz/MethodsTooLong` max of 5 lines.
class MetzOffender
  def too_long_method
    a = 1
    b = 1
    c = 1
    d = 1
    e = 1
    f = 1
    g = 1
    [a, b, c, d, e, f, g]
  end
end
