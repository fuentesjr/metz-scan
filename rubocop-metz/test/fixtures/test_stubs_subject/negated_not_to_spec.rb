# frozen_string_literal: true

RSpec.describe Widget do
  it "negates with not_to" do
    expect(subject).not_to receive(:save)
  end
end
