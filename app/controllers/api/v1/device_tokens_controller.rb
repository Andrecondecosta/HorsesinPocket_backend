class Api::V1::DeviceTokensController < ApplicationController
  before_action :authorized

  def create
    device_token = current_user.device_tokens.find_or_initialize_by(token: params[:token])

    device_token.platform = params[:platform] || 'ios'
    device_token.active = true
    device_token.touch_last_used

    if device_token.save
      render json: { message: 'Device token guardado com sucesso' }, status: :created
    else
      render json: { errors: device_token.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    device_token = current_user.device_tokens.find_by(token: params[:token])

    if device_token
      device_token.update(active: false)
      render json: { message: 'Device token desativado com sucesso' }, status: :ok
    else
      render json: { error: 'Device token não encontrado' }, status: :not_found
    end
  end
end
