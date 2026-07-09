# frozen_string_literal: true

RSpec.describe Widget do
  it "uses receive_message_chain" do
    allow(subject).to receive_message_chain(:account, :name)
  end
end
