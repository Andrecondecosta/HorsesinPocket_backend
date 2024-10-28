class Api::V1::XraysController < ApplicationController
  before_action :set_horse

  # Upload de uma imagem de raio-X para um cavalo
  def create
    @xray = @horse.xrays.build(xray_params)

    if @xray.save
      render json: { url: url_for(@xray.image), message: 'Raio-X carregado com sucesso' }, status: :created
    else
      render json: @xray.errors, status: :unprocessable_entity
    end
  end

  # Exclui uma imagem de raio-X
  def destroy
    @xray = @horse.xrays.find(params[:id])
    @xray.destroy
    head :no_content
  end

  private

  # Encontra o cavalo associado ao raio-X
  def set_horse
    @horse = current_user.horses.find(params[:horse_id])
  end

  # Permite os parâmetros permitidos para o upload de raio-X
  def xray_params
    params.require(:xray).permit(:image)
  end
end
