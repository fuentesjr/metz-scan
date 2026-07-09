# frozen_string_literal: true

RSpec.describe Widget do
  it "uses receive_messages" do
    allow(subject).to receive_messages(save: true)
  end
end
