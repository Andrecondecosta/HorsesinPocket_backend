Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :horses do
        post :share, on: :member
        get :received, on: :collection
        resources :ancestors, only: [:index, :create, :update, :destroy]
        # Rotas aninhadas para as mídias
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

  # Adicione esta rota para lidar com todas as rotas desconhecidas (catch-all)
  get '*path', to: 'application#frontend_index', constraints: ->(req) { !req.xhr? && req.format.html? }
end
