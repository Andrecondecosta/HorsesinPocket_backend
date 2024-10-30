# app/controllers/api/v1/horses_controller.rb
class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy]

  def index
    @horses = current_user.horses.includes(images_attachments: :blob)
    render json: @horses.map { |horse|
      horse.as_json.merge({
        images: horse.images.map { |image| url_for(image) }
      })
    }
  end

  def show
    render json: @horse.as_json.merge({
      images: @horse.images.map { |image| url_for(image) }
    })
  end

  def create
    @horse = current_user.horses.build(horse_params)
    if @horse.save
      if params[:horse][:images] && @horse.images.blank?
        params[:horse][:images].each do |image|
          @horse.images.attach(image)
        end
      end
      render json: @horse.as_json.merge({
        images: @horse.images.map { |image| url_for(image) }
      }), status: :created
    else
      render json: @horse.errors, status: :unprocessable_entity
    end
  end

  # app/controllers/api/v1/horses_controller.rb
  def update
    if @horse.update(horse_params)
      # Remove imagens especificadas em deleted_images
      if params[:deleted_images]
        params[:deleted_images].each do |image_url|
          image = @horse.images.find { |img| url_for(img) == image_url }
          image.purge if image
        end
      end

      # Anexa novas imagens, se existirem
      if params[:horse][:images]
        params[:horse][:images].each do |image|
          @horse.images.attach(image)
        end
      end

      render json: @horse.as_json.merge({
        images: @horse.images.map { |image| url_for(image) }
      })
    else
      render json: @horse.errors, status: :unprocessable_entity
    end
  end



  def destroy
    @horse.images.purge if @horse.images.attached?
    @horse.destroy
    head :no_content
  end

  private

  def set_horse
    @horse = current_user.horses.find(params[:id])
  end

  def horse_params
    params.require(:horse).permit(:name, :age, :description, images: [])
  end
end
