class ApplicationController < ActionController::API
  before_action :authorized

  def authorized
    render json: { error: 'Unauthorized' }, status: :unauthorized unless logged_in?
  end

  def logged_in?
    !!current_user
  end

  def current_user
    @current_user ||= begin
      if decoded_token
        user_id = decoded_token[0]['user_id']
        User.find_by(id: user_id)
      end
    end
  end

  def decoded_token
    if auth_header
      token = auth_header.split(' ')[1]
      begin
        JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
      rescue JWT::DecodeError
        nil
      end
    end
  end

  def auth_header
    request.headers['Authorization']
  end

  def encode_token(payload)
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
  def authorize_admin
    unless current_user&.admin?
      render json: { error: 'Acesso negado' }, status: :forbidden
    end
  end

end
