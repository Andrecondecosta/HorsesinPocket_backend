class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  # Cria um novo usuário (signup)
  def create
    user = User.new(user_params)

    if user.save
      token = encode_token({ user_id: user.id })
      render json: { token: token, message: 'Usuário criado com sucesso!' }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Parâmetros permitidos para criar o usuário
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  # Gera o token JWT
  def encode_token(payload)
    JWT.encode(payload, Rails.application.secrets.secret_key_base)
  end
end
