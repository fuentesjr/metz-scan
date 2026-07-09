# frozen_string_literal: true

RSpec.describe Widget do
  it "uses have_received" do
    expect(subject).to have_received(:save)
  end
end
