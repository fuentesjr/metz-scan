# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @user = User.current
    @orders = Order.recent
    @posts = Post.featured
    @stats = StatsService.compute
    Tracker.record(:dashboard)
  end
end
