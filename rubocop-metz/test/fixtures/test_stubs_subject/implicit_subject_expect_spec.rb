# frozen_string_literal: true

RSpec.describe Widget do
  it "expects a subject message" do
    expect(subject).to receive(:save)
  end
end
