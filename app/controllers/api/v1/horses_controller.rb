class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy]

  # Lista todos os cavalos do usuário autenticado
  def index
    @horses = current_user.horses.includes(images_attachments: :blob)
    render json: @horses.map { |horse|
      horse.as_json.merge({
        images: horse.images.map { |image| url_for(image) }
      })
    }
  end

  # Exibe um cavalo específico e suas mídias
  def show
    render json: @horse.as_json.merge({
      images: @horse.images.map { |image| url_for(image) }
    })
  end

  # Cria um novo cavalo
  def create
    @horse = current_user.horses.build(horse_params)
    if @horse.save
      attach_images(params[:horse][:images]) if params[:horse][:images].present?
      render json: @horse.as_json.merge({
        images: @horse.images.map { |image| url_for(image) }
      }), status: :created
    else
      render json: @horse.errors, status: :unprocessable_entity
    end
  end

  # Atualiza um cavalo existente
  def update
    ActiveRecord::Base.transaction do
      if @horse.update(horse_params)
        purge_images if params[:deleted_images].present?
        attach_images(params[:horse][:images]) if params[:horse][:images].present?

        render json: @horse.as_json.merge(images: @horse.images.map { |img| url_for(img) })
      else
        render json: @horse.errors, status: :unprocessable_entity
      end
    end
  end

  # Deleta um cavalo
  def destroy
    @horse.images.purge if @horse.images.attached?
    @horse.destroy
    head :no_content
  end

  private

  # Função que purga imagens específicas do cavalo
  def purge_images
    params[:deleted_images].each do |image_url|
      image = @horse.images.find { |img| url_for(img) == image_url }
      image.purge if image
    end
  end

  # Função para anexar novas imagens, evitando duplicações
  def attach_images(new_images)
    new_images.each do |image|
      unless @horse.images.map(&:filename).include?(image.original_filename)
        @horse.images.attach(image)
      end
    end
  end

  def horse_params
    params.require(:horse).permit(
      :name, :age, :height_cm, :description, :gender, :color, :training_level, :piroplasmosis, images: [])
  end


  def set_horse
    @horse = current_user.horses.find(params[:id])
  end
end
