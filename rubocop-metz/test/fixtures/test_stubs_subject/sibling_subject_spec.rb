# frozen_string_literal: true

RSpec.describe Widget do
  context "with a named subject" do
    subject(:svc) { described_class.new }
  end

  context "sibling" do
    it "does not inherit the sibling subject name" do
      allow(svc).to receive(:save)
    end
  end
end
