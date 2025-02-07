class Api::V1::SessionsController < ApplicationController
  skip_before_action :authorized, only: [:create]

  def create
    user = User.find_by(email: params[:email])

    if user && user.valid_password?(params[:password])

      if params[:shared_token].present?
        Rails.logger.info("Received shared_token: #{params[:shared_token]}") # Verifica no log do Rails

        shared_link = SharedLink.find_by(token: params[:shared_token])

        if shared_link
          # Associa o cavalo ao usuário
          UserHorse.create!(
            horse_id: shared_link.horse_id,
            user_id: user.id,
            shared_by: shared_link.horse.user_id
          )

          # Marca o link como usado
          shared_link.update!(status: 'used')
          Rails.logger.info("Cavalo #{shared_link.horse_id} associado ao usuário #{user.id} com sucesso!")
        else
          Rails.logger.info("Token de compartilhamento inválido")
        end
      else
        Rails.logger.info("Nenhum shared_token foi fornecido")
      end


      token = encode_token({ user_id: user.id })
      render json: { token: token }, status: :ok
    else
      render json: { error: 'Invalid username or password' }, status: :unauthorized
    end
  end

  def confirm_email
    user = User.find_by(id: params[:id])

    if user && !user.email_confirmed?
      user.update(email_confirmed: true, confirmed_at: Time.current)
      render json: { message: "Email confirmado com sucesso!" }, status: :ok
    else
      render json: { error: "Email já confirmado ou inválido." }, status: :unprocessable_entity
    end
  end
end
