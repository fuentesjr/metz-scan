# frozen_string_literal: true

RSpec.describe Widget do
  let(:collaborator) { instance_double("Collaborator") }

  it "stubs a collaborator" do
    allow(collaborator).to receive(:save)
  end
end
