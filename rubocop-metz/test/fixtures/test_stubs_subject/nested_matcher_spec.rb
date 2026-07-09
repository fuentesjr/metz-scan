# frozen_string_literal: true

RSpec.describe Widget do
  it "nests the stub matcher" do
    expect(subject).to all(receive(:save))
  end
end
