class Api::V1::PhotosController < ApplicationController
  before_action :set_horse

  # Upload de uma foto para um cavalo
  def create
    @photo = @horse.photos.build

    if params[:photo][:image]
      # Criando o blob manualmente com a pasta "HorsesInPocket"
      blob = ActiveStorage::Blob.create_after_upload!(
        io: params[:photo][:image].tempfile, # arquivo de imagem
        filename: params[:photo][:image].original_filename, # nome original do arquivo
        content_type: params[:photo][:image].content_type,  # tipo de conteúdo
        service_name: 'cloudinary',  # serviço cloudinary
        key: "HorsesInPocket/#{SecureRandom.hex}/#{params[:photo][:image].original_filename}"  # chave personalizada com a pasta
      )

      # Associando o blob à imagem da foto
      @photo.image.attach(blob)
    end

    if @photo.save
      render json: { url: url_for(@photo.image), message: 'Foto carregada com sucesso' }, status: :created
    else
      render json: @photo.errors, status: :unprocessable_entity
    end
  end

  private

  # Encontra o cavalo associado à foto
  def set_horse
    @horse = current_user.horses.find(params[:horse_id])
  end

  # Permite os parâmetros permitidos para o upload de foto
  def photo_params
    params.require(:photo).permit(:image)
  end
end
