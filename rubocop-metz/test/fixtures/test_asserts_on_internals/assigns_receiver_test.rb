# frozen_string_literal: true

class UsersControllerTest
  def test_receiver_assigns_is_unrelated
    assert_equal user, controller.assigns(:user)
  end
end
