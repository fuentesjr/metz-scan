# frozen_string_literal: true

RSpec.describe Widget do
  subject!(:svc) { described_class.new }

  it "allows a bang subject message" do
    allow(svc).to receive(:save)
  end
end
