# frozen_string_literal: true

Rails.application.routes.draw do
  root "runs#index"

  resources :runs, only: [:index, :show] do
    member do
      post :rerun
    end
  end

  post "/webhooks", to: "webhooks#create"
  post "/webhook", to: "webhooks#create"

  get "/health", to: proc { [200, { "Content-Type" => "application/json" }, ['{"status":"ok","service":"solid_run"}']] }
end
