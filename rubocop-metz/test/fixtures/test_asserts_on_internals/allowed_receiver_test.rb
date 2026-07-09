# frozen_string_literal: true

class WidgetTest
  def test_allowed_receiver
    reflection_target.instance_variable_get(:@x)
  end
end
