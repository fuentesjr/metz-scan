# frozen_string_literal: true

class OrdersController < ApplicationController
  def create
    @order = Order.create(order_params)
    Inventory.reserve(@order)
    Mailer.confirmation(@order).deliver_later
    PaymentGateway.charge(@order)
  end

  def show
    @order = Order.find(params[:id])
    @items = LineItem.for_order(@order)
    Analytics.track("order.viewed", @order.id)
  end
end
