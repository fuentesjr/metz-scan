# frozen_string_literal: true

class WidgetTest
  def test_safe_navigation_send
    widget&.send(:bar)
  end
end
