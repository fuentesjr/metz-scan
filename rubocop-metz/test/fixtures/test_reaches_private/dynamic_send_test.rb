# frozen_string_literal: true

class WidgetTest
  def test_dynamic_dispatch
    widget.send(:"#{attribute}")
    widget.send(method_name)
  end
end
