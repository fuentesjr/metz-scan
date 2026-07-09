# frozen_string_literal: true

RSpec.describe Widget do
  subject(:svc) { described_class.new }

  context "nested" do
    it "inherits the subject name" do
      allow(svc).to receive(:save)
    end
  end
end
