class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  before_action :authorized, except: [:create]

  def show
    render json: current_user, status: :ok
  end

  def create
    user = User.new(user_params)

    if user.save
      UserMailer.confirmation_email(user).deliver_later
      token = encode_token({ user_id: user.id }) # Gera o token JWT
      render json: { token: token, message: 'Usuário criado com sucesso!' }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end


  def update
    if current_user.update(user_params)
      render json: current_user, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :birthdate, :phone_number, :address, :gender)
  end
end
