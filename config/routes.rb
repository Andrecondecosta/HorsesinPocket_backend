Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :horses do
        post :share_via_email, on: :member
        post :share_via_link, on: :member
        get :received, on: :collection
        resources :ancestors, only: [:index, :create, :update, :destroy]
        resources :photos, only: [:create, :destroy]
        resources :videos, only: [:create, :destroy]
        resources :xrays, only: [:create, :destroy]
      end

      resources :logs, only: [:index]
      post '/login', to: 'sessions#create'
      post '/signup', to: 'registrations#create'
      get '/profile', to: 'registrations#show'
      put '/update', to: 'registrations#update'
      get '/received', to: 'horses#received_horses'
      get 'home/index'
    end
  end

  # Rota para links partilhados, fora do namespace
  get 'horses/shared/:token', to: 'horses#shared', as: :shared_horse
end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # Defines the root path route ("/")
  # root "posts#index"
