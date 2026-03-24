Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do

      # Sessions
      post '/login', to: 'sessions#create'
      delete '/logout', to: 'sessions#destroy'

      # Registrations
      post '/register', to: 'registrations#create'
      get '/profile', to: 'registrations#show'
      put '/update', to: 'registrations#update'

      # Passwords
      post '/forgot_password', to: 'passwords#forgot'
      post '/reset_password', to: 'passwords#reset'

      # Countries
      get 'countries', to: 'countries#index'

      # Horses
      resources :horses do
        collection do
          get 'shared/:token', to: 'horses#shared', as: 'shared'
        end
        member do
          delete :delete_shares
          get :shares
          get :pending_approvals
        end
        resources :screenshots, only: [:create]
      end

      # User Horses
      resources :user_horses, only: [] do
        member do
          post :approve_screenshot
          post :reject_screenshot
        end
      end

      # Logs
      resources :logs, only: [:index]

      # Users
      get '/user_status', to: 'users#status'
      get '/received_horses', to: 'users#received_horses'

      # Payments
      post '/payments/create_payment_intent', to: 'payments#create_payment_intent'
      post '/payments/create_setup_intent', to: 'payments#create_setup_intent'
      post '/payments/cancel_subscription', to: 'payments#cancel_subscription'
      post '/change_plan', to: 'payments#change_plan'
      get '/get_user_plan', to: 'payments#get_user_plan'

      # Admin
      namespace :admin do
        get '/dashboard', to: 'dashboard#index'
      end
    end
  end
end
