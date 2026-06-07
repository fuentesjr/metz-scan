# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    @session = Session.new
  end

  def create
    @session = Session.authenticate(params[:email], params[:password])
  end

  def destroy
    Session.terminate(current_session_id)
  end
end
