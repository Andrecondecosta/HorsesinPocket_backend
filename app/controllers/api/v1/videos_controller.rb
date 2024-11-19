class Api::V1::VideosController < ApplicationController
  before_action :set_horse

  # Upload de um vídeo para um cavalo
  def create
    @video = @horse.videos.build

    if params[:video][:file]
      # Criando o blob manualmente para enviar ao Cloudinary
      blob = ActiveStorage::Blob.create_after_upload!(
        io: params[:video][:file].tempfile,
        filename: params[:video][:file].original_filename,
        content_type: params[:video][:file].content_type,
        service_name: 'cloudinary',
        key: "HorsesInPocket/Videos/#{SecureRandom.hex}/#{params[:video][:file].original_filename}"
      )

      # Associando o blob ao vídeo
      @video.video.attach(blob)
    end

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
end
