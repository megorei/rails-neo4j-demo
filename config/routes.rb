Rails.application.routes.draw do
  resources :drugs,   only: :index
  resources :doctors, only: :index
  root to: 'home#index'
end
