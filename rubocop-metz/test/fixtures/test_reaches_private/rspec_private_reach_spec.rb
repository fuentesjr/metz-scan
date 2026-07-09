# frozen_string_literal: true

RSpec.describe Widget do
  it "reaches private behavior" do
    subject.send(:private_thing)
  end
end
