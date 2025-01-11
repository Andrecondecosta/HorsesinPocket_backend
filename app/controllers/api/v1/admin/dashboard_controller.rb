module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        before_action :authorized
        before_action :authorize_admin

        def index
          @user_count = User.count
          @horse_count = Horse.count
          @log_count = Log.count

          render json: {
            total_users: @user_count,
            total_horses: @horse_count,
            total_logs: @log_count
          }
        end

        def statistics
          render json: {
            total_horses: Horse.count,
            total_users: User.count,
            total_logs: Log.count
          }
        end

        def users
          @users = User.all
          render json: @users
        end

        def horses
          @horses = Horse.all
          render json: @horses
        end

        def logs
          @logs = Log.order(created_at: :desc).limit(50)
          render json: @logs
        end

        private

        def authorize_admin
          unless current_user&.admin?
            render json: { error: 'Acesso negado' }, status: :forbidden
          end
        end
      end
    end
  end
end
