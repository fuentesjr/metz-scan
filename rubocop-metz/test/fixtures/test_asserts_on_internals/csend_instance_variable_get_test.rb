# frozen_string_literal: true

class WidgetTest
  def test_safe_navigation_internal_read
    foo&.instance_variable_get(:@x)
  end
end
