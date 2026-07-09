# frozen_string_literal: true

RSpec.describe Widget do
  it "does not treat described_class as the subject" do
    allow(described_class).to receive(:new)
  end
end
