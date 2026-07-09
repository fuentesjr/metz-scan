# frozen_string_literal: true

class UsersControllerTest
  def test_reads_assigned_user
    assert_equal user, assigns(:user)
  end
end
