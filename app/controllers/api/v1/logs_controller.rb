class Api::V1::LogsController < ApplicationController
  before_action :authorized
  def index
    @logs = Log.where(user_id: current_user.id)
    .order(created_at: :desc)
    .limit(11) # Retorna as 3 últimas ações


    # Log the JSON response for debugging
    response_data = @logs.map { |log|
      {
        id: log.id,
        action: log.action,
        horse_name: log.horse_name || 'N/A', # Substitui nil por 'N/A'
        recipient: log.recipient || 'N/A',  # Substitui nil por 'N/A'
        created_at: log.created_at.strftime('%Y-%m-%d %H:%M')
      }
    }

    Rails.logger.info("Response Data: #{response_data.inspect}")

    render json: response_data, status: :ok
  end

end
