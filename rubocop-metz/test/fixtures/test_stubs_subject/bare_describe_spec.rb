# frozen_string_literal: true

describe Widget do
  it "allows a subject message" do
    allow(subject).to receive(:save)
  end
end
