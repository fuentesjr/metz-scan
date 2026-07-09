# frozen_string_literal: true

class WidgetTest
  def setup
    @user = User.new
  end

  def test_uses_fixture_state
    @user.name = "Sal"
    assert_equal "Sal", @user.name
  end
end
