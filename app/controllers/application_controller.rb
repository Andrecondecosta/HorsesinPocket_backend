class ApplicationController < ActionController::API
  before_action :authorized

  def authorized
    render json: { error: 'Unauthorized' }, status: :unauthorized unless logged_in?
  end

  def logged_in?
    !!current_user
  end

  def current_user
    return @current_user if @current_user # Retorna se já foi definido
    decoded = decoded_token
    @current_user = User.find_by(id: decoded[0]['user_id']) if decoded
  end


  def decoded_token
    return nil unless auth_header

    token = auth_header.split(' ')[1]
    JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
  rescue JWT::ExpiredSignature
    Rails.logger.warn("JWT Expired Token: #{token}")
    nil
  rescue JWT::DecodeError => e
    Rails.logger.warn("JWT Decode Error: #{e.message}")
    nil
  end


  def auth_header
    request.headers['Authorization']
  end

  def encode_token(payload)
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end

  def frontend_index
    render file: Rails.root.join('public', 'index.html'), layout: false
  end
end
