# frozen_string_literal: true

RSpec.describe Widget do
  it "negates with to_not" do
    expect(subject).to_not receive(:save)
  end
end
