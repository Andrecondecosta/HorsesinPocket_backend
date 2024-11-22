Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :horses do
        resources :ancestors, only: [:index, :create, :update, :destroy]
        # Rotas aninhadas para as mídias
        resources :photos, only: [:create, :destroy]
        resources :videos, only: [:create, :destroy]
        resources :xrays, only: [:create, :destroy]
      end
      post '/login', to: 'sessions#create'
      post '/signup', to: 'registrations#create'
      get '/profile', to: 'registrations#show'
      put '/update', to: 'registrations#update'
      get 'home/index'
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root "api/v1/horses#index"
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  match '*path', to: 'application#not_found', via: :all
  # Defines the root path route ("/")
  # root "posts#index"
end
