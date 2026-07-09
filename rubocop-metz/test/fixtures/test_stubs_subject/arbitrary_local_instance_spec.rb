# frozen_string_literal: true

RSpec.describe Widget do
  it "does not infer arbitrary locals as subject" do
    widget = described_class.new

    allow(widget).to receive(:save)
  end
end
