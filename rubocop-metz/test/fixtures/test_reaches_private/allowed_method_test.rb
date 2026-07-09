# frozen_string_literal: true

class WidgetTest
  def test_metaprogramming
    widget.send(:define_method, :thing) { true }
  end
end
