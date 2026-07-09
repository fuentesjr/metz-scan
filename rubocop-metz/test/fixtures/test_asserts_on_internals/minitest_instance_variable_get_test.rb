# frozen_string_literal: true

class WidgetTest
  def test_reads_internal_count
    assert_equal 1, obj.instance_variable_get(:@count)
  end
end
