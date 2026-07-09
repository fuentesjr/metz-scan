# frozen_string_literal: true

RSpec.describe Widget do
  subject(:svc) { described_class.new }
  let(:svc) { instance_double("Collaborator") }

  it "treats the let as a collaborator override" do
    allow(svc).to receive(:save)
  end
end
