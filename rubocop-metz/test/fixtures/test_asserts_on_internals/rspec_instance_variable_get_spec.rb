# frozen_string_literal: true

RSpec.describe Widget do
  it "reads internal count" do
    expect(subject.instance_variable_get(:@count)).to eq(1)
  end
end
