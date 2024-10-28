class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy]

  # Lista todos os cavalos do usuário autenticado
  def index
    @horses = current_user.horses.includes(image_attachment: :blob)
    render json: @horses.map { |horse|
      horse.as_json.merge({
        image_url: horse.image.attached? ? url_for(horse.image) : nil
      })
    }
  end

  # Exibe um cavalo específico e suas mídias
  def show
    render json: @horse.as_json.merge({
      image_url: @horse.image.attached? ? url_for(@horse.image) : nil
    })
  end

  # Cria um novo cavalo
  def create
    @horse = current_user.horses.build(horse_params)

    if @horse.save
      if params[:horse][:image]
        @horse.image.attach(params[:horse][:image])
      end
      render json: @horse.as_json.merge({
        image_url: @horse.image.attached? ? url_for(@horse.image) : nil
      }), status: :created
    else
      render json: @horse.errors, status: :unprocessable_entity
    end
  end

  # Atualiza um cavalo existente
  def update
    if @horse.update(horse_params)
      render json: @horse.as_json.merge({
        image_url: @horse.image.attached? ? url_for(@horse.image) : nil
      })
    else
      render json: @horse.errors, status: :unprocessable_entity
    end
  end

  # Deleta um cavalo
  def destroy
    @horse.image.purge if @horse.image.attached?
    @horse.destroy
    head :no_content
  end

  private

  # Encontra o cavalo baseado no ID
  def set_horse
    @horse = current_user.horses.find(params[:id])
  end

  # Permite os parâmetros permitidos para criação e atualização de cavalo
  def horse_params
    params.require(:horse).permit(:name, :age, :description, :image)
  end
end
