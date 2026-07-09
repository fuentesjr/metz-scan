# frozen_string_literal: true

RSpec.describe Widget do
  it "uses safe navigation on the runner" do
    expect(subject)&.to receive(:save)
  end
end
