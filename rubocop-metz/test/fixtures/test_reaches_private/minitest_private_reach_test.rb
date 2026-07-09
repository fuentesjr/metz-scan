# frozen_string_literal: true

class WidgetTest
  def test_reaches_private
    widget.send(:private_thing)
  end
end
