# frozen_string_literal: true

class CapturePayment
  def initialize(order)
    @order = order
  end

  def call
    @order
  end
end
