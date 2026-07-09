# frozen_string_literal: true

class WidgetTest
  def test_operator_dispatch
    widget.send(:==, other)
    send(:+, 1)
  end
end
