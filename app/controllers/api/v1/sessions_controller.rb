class Api::V1::SessionsController < ApplicationController
  skip_before_action :authorized, only: [:create]

  def create
    user = User.find_by(email: params[:email])

    if user && user.valid_password?(params[:password])
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
