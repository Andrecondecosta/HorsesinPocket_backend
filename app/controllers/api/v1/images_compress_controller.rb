
class Api::V1::ImagesCompressController < ApplicationController
  before_action :authorized # Garante que o usuário está autenticado

  def compress
    uploaded_file = params[:file]

    # Verifica se o arquivo foi enviado corretamente
    unless uploaded_file.is_a?(ActionDispatch::Http::UploadedFile)
      render json: { error: 'Nenhuma imagem válida enviada.' }, status: :unprocessable_entity
      return
    end

    begin
      compressed_image = MiniMagick::Image.read(uploaded_file.tempfile)
      compressed_image.resize "800x800>" # Redimensiona, ajuste conforme necessário
      compressed_image.quality 80        # Ajusta a qualidade da imagem

      send_data compressed_image.to_blob,
                type: compressed_image.mime_type,
                disposition: 'inline'
    rescue StandardError => e
      render json: { error: "Erro ao processar a imagem: #{e.message}" }, status: :unprocessable_entity
    end
  end
end
