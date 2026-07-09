# frozen_string_literal: true

class WidgetTest
  def test_allowed_receiver
    reflection_target.send(:private_thing)
  end
end
