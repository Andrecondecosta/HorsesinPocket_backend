class Api::V1::UserHorsesController < ApplicationController
   before_action :authorized
  before_action :set_user_horse, only: [:approve_screenshot, :reject_screenshot]
  before_action :authorize_creator!, only: [:approve_screenshot, :reject_screenshot]

  def approve_screenshot
    if @user_horse.update(status: "active")
      create_log(
        action: "approved_share",
        horse_name: @user_horse.horse.name,
        recipient: @user_horse.user.name
      )
      render json: { message: "Partilha aprovada e desbloqueada." }, status: :ok
    else
      render json: { error: "Erro ao aprovar." }, status: :unprocessable_entity
    end
  end

  def reject_screenshot
    if @user_horse.update(status: "revoked")
      create_log(
        action: "revoked_share",
        horse_name: @user_horse.horse.name,
        recipient: @user_horse.user.name
      )
      render json: { message: "Partilha revogada e cavalo removido." }, status: :ok
    else
      render json: { error: "Erro ao rejeitar." }, status: :unprocessable_entity
    end
  end

  private

  def set_user_horse
    @user_horse = UserHorse.find(params[:id])
  end

  def authorize_creator!
    unless current_user.id == @user_horse.horse.user_id
      render json: { error: "Não autorizado" }, status: :unauthorized
    end
  end
end
