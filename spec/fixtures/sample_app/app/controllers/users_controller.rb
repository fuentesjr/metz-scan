# frozen_string_literal: true

class UsersController < ApplicationController
  def index
    @users = User.all
    @audit = AuditLog.recent
    @notifier = Notifier.deliver_later
  end

  def show
    @user = User.find(params[:id])
    @posts = Post.where(user_id: @user.id)
    Tracker.record(@user)
  end
end
