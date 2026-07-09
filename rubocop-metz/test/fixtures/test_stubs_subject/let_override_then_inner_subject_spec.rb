# frozen_string_literal: true

RSpec.describe Widget do
  let(:svc) { instance_double("Collaborator") }

  context "with a nearer subject" do
    subject(:svc) { described_class.new }

    it "re-adds the subject name" do
      allow(svc).to receive(:save)
    end
  end
end
