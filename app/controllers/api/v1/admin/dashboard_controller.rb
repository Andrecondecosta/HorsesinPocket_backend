module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        before_action :authorized
        before_action :authorize_admin
        before_action :set_user, only: [:destroy_user]

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

        def destroy_user
          ActiveRecord::Base.transaction do
            Rails.logger.info("🗑️ Deletando cavalos do usuário #{@user.id}")
            @user.horses.destroy_all

            Rails.logger.info("🗑️ Deletando compartilhamentos do usuário #{@user.id}")
            @user.user_horses.destroy_all

            if @user.destroy
              Rails.logger.info("✅ Usuário #{@user.id} deletado com sucesso.")
              render json: { message: "Usuário excluído com sucesso." }, status: :ok
            else
              Rails.logger.error("❌ Falha ao deletar usuário: #{@user.errors.full_messages}")
              render json: { error: "Erro ao excluir o usuário." }, status: :unprocessable_entity
            end
          end
        rescue => e
          Rails.logger.error("❌ Erro ao deletar usuário: #{e.message}")
          render json: { error: "Erro ao excluir usuário: #{e.message}" }, status: :internal_server_error
        end





        private

        def authorize_admin
          unless current_user&.admin?
            render json: { error: 'Acesso negado' }, status: :forbidden
          end
        end

        def set_user
          @user = User.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Usuário não encontrado." }, status: :not_found
        end
      end
    end
  end
end
