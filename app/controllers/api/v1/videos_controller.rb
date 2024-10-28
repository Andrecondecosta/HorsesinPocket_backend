class Api::V1::VideosController < ApplicationController
  before_action :set_horse

  # Upload de um vídeo para um cavalo
  def create
    @video = @horse.videos.build(video_params)

    if @video.save
      render json: { url: url_for(@video.video), message: 'Vídeo carregado com sucesso' }, status: :created
    else
      render json: @video.errors, status: :unprocessable_entity
    end
  end

  # Exclui um vídeo
  def destroy
    @video = @horse.videos.find(params[:id])
    @video.destroy
    head :no_content
  end

  private

  # Encontra o cavalo associado ao vídeo
  def set_horse
    @horse = current_user.horses.find(params[:horse_id])
  end

  # Permite os parâmetros permitidos para o upload de vídeo
  def video_params
    params.require(:video).permit(:video)
  end
end
