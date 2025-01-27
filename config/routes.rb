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
        collection do
          get 'shared/:token', to: 'horses#shared', as: 'shared'
        end

        member do
          delete :delete_shares
        end
      end
      resource :password, only: [] do
        collection do
          post :forgot
          patch :reset
        end
      end
      resources :users do
        member do
          get :confirm_email
        end
      end

      post 'images_compress/compress', to: 'images_compress#compress'
      post 'videos_compress/compress', to: 'videos_compress#compress'
      post '/login', to: 'sessions#create'
      post '/signup', to: 'registrations#create'
      get '/profile', to: 'registrations#show'
      put '/update', to: 'registrations#update'
      get '/received', to: 'horses#received_horses'

      # Rotas de planos
      get 'get_user_plan', to: 'users#get_user_plan'
      post '/change_plan', to: 'users#change_plan'

      # Rotas do Stripe
      post '/stripe/customers', to: 'stripe#create_customer'
      # Rotas de autenticação
      post '/webhooks/stripe', to: 'webhooks#receive'

      # Rotas de subscrição
      resources :subscriptions, only: [:create]

      # Rotas administrativas
      resources :logs, only: [:index]

      namespace :admin do
        get '/dashboard', to: 'dashboard#index'
        get '/statistics', to: 'dashboard#statistics'
        get '/users', to: 'dashboard#users'
        get '/horses', to: 'dashboard#horses'
        get '/logs', to: 'dashboard#logs'
      end
    end
  end
end
