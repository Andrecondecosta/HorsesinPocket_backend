Rails.application.routes.draw do
  get 'screenshots/create'
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
          get :shares
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
      resources :user_horses, only: [] do
        member do
          post 'approve_screenshot'
          post 'reject_screenshot'
        end
      end
      get "/user_status", to: "users#get_user_status"
      get 'countries', to: 'countries#index'
      post 'images_compress/compress', to: 'images_compress#compress'
      post 'videos_compress/compress', to: 'videos_compress#compress'
      post '/login', to: 'sessions#create'
      post '/signup', to: 'registrations#create'
      get '/profile', to: 'registrations#show'
      put '/update', to: 'registrations#update'
      get '/received', to: 'horses#received_horses'
      get '/welcome', to: 'static_pages#welcome'
      post '/screenshots', to: 'screenshots#create'


      # Rotas de pagamento
      resources :payments, only: [] do
        post "create_setup_intent", on: :collection
        post "create_payment_intent", on: :collection
      end

      # Rotas de planos
      get 'get_user_plan', to: 'users#get_user_plan'
      post '/change_plan', to: 'users#change_plan'

      # Rotas do Stripe
      post '/stripe/customers', to: 'stripe#create_customer'
      # Rotas de autenticação
      post '/webhooks/stripe', to: 'webhooks#receive'

      resources :subscriptions, only: [] do
        collection do
          post 'create_or_renew' # ⬅️ Permite acessar /api/v1/subscriptions/create_or_renew
        end
      end
      resources :payments, only: [] do
        post "cancel_subscription", on: :collection
      end

      # Rotas administrativas
      resources :logs, only: [:index]

      namespace :admin do
        get '/dashboard', to: 'dashboard#index'
        get '/statistics', to: 'dashboard#statistics'
        get '/users', to: 'dashboard#users'
        delete '/users/:id', to: 'dashboard#destroy_user'
        get '/horses', to: 'dashboard#horses'
        get '/logs', to: 'dashboard#logs'
      end
    end
  end
end
