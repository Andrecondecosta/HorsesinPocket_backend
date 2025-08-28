class Api::V1::ScreenshotsController < ApplicationController
  before_action :authorized

 def create
  horse = Horse.find(params[:horse_id])

  # Ignora se for o criador do cavalo
  return head :ok if horse.user_id == current_user.id

  user_horse = UserHorse.find_by(user: current_user, horse: horse)

  if user_horse
    user_horse.update!(status: "pending_approval")
  end

  ScreenshotEvent.create!(user_id: current_user.id, horse_id: horse.id)

  head :created
end
end
