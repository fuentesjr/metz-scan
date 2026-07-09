# frozen_string_literal: true

class UsersControllerTest
  def test_dynamic_assigns_names_are_ignored
    assert_equal user, assigns(name)
    assert_equal user, assigns(:"#{name}")
    assert_equal user, assigns("#{name}")
  end
end
