# frozen_string_literal: true

RSpec.describe UsersController do
  it "reads assigned user" do
    expect(assigns(:user)).to eq(user)
  end
end
