# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  resources :users
  resources :orders
  resources :sessions, only: %i[new create destroy]

  get "dashboard", to: "dashboard#show"
  get "health", to: "health#index"
end
