class Api::V1::ScreenshotsController < ApplicationController
  before_action :authorized

  def create
    horse = Horse.find_by(id: params[:horse_id])

    unless horse
      return render json: { error: "Cavalo não encontrado." }, status: :not_found
    end

    # Só pode ver se já tem acesso ao cavalo
    unless horse.shared_with?(current_user) || horse.user_id == current_user.id
      return render json: { error: "Não autorizado." }, status: :unauthorized
    end

    # Regista o evento
    ScreenshotEvent.create(user: current_user, horse: horse)

    # Marca o cavalo como "a aguardar aprovação"
    UserHorse.where(user: current_user, horse: horse).update_all(status: "pending_approval")

    # TODO: Notificar o criador do cavalo (pode ser via ActionMailer, Push Notification, etc.)

    render json: { message: "📸 Screenshot registado com sucesso." }, status: :ok
  end
end
