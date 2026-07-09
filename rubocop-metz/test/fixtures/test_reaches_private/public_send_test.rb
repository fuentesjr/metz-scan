# frozen_string_literal: true

class WidgetTest
  def test_public_send
    widget.public_send(:thing)
  end
end
