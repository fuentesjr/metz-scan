# frozen_string_literal: true

class OrdersController < ApplicationController
  def create
    ValidateOrder.call(order)
    ReserveInventory.call(order)
    CapturePayment.new(order).call
    SendReceipt.call(order)
  end

  private

  def order
    @order
  end
end
