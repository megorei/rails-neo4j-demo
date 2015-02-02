Rails.application.routes.draw do
  resources :drugs
  resources :doctors
  root to: 'home#index'
end
