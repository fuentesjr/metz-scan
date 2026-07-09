# frozen_string_literal: true

class WidgetTest
  def test_underscore_send
    widget.__send__(:private_thing)
  end
end
