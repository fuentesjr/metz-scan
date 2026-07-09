# frozen_string_literal: true

class WidgetTest
  def test_sets_internal_state
    obj.instance_variable_set(:@state, :ready)
  end
end
