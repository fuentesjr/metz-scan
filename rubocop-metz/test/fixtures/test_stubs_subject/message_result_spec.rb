# frozen_string_literal: true

RSpec.describe Widget do
  it "expects on a message result" do
    expect(subject.foo).to receive(:save)
  end
end
