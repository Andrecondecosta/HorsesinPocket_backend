class Api::V1::PasswordsController < ApplicationController
  skip_before_action :authorized, only: [:forgot, :reset]

  def forgot
    user = User.find_by(email: params[:email])
    if user
      token = SecureRandom.hex(10) # Ou o método que você usa para gerar tokens
      user.update(reset_password_token: token, reset_password_sent_at: Time.now.utc)
      UserMailer.password_reset_email(user, token).deliver_now
      render json: { message: 'E-mail de redefinição enviado.' }, status: :ok
    else
      render json: { error: 'Usuário não encontrado.' }, status: :not_found
    end
  end

  def reset
    user = User.find_by(reset_password_token: params[:token])

    if user && user.reset_password_sent_at > 2.hours.ago
      if user.update(password: params[:password])
        render json: { message: 'Senha redefinida com sucesso!' }, status: :ok
      else
        render json: { error: 'Não foi possível redefinir a senha.' }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Token inválido ou expirado.' }, status: :unauthorized
    end
  end
end
