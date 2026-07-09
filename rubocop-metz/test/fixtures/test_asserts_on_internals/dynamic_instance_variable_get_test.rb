# frozen_string_literal: true

class WidgetTest
  def test_reads_dynamic_internal_name
    assert_equal 1, obj.instance_variable_get(ivar_name)
  end
end
