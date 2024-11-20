class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy]

  # Lista todos os cavalos do usuário autenticado
  def index
    @horses = current_user.horses.includes(:ancestors, images_attachments: :blob, videos_attachments: :blob)
    render json: @horses.map { |horse|
      horse.as_json.merge({
        images: horse.images.map { |image| url_for(image) },
        videos: horse.videos.map { |video| url_for(video) },
        ancestors: horse.ancestors
      })
    }
  end

  # Exibe um cavalo específico e suas mídias
  def show
    render json: @horse.as_json.merge({
      images: @horse.images.map { |image| url_for(image) },
      videos: @horse.videos.map { |video| url_for(video) },
      ancestors: @horse.ancestors
    })
  end

  # Cria um novo cavalo
  def create
    @horse = current_user.horses.build(horse_params)

    if @horse.save
      # Processa ancestrais apenas se `ancestors_attributes` for um array
      if params[:horse][:ancestors_attributes].is_a?(Array)
        params[:horse][:ancestors_attributes].each do |ancestor_params|
          # Ignora se `ancestor_params` estiver ausente ou incompleto
          next unless ancestor_params.is_a?(Hash) && ancestor_params[:relation_type].present? && ancestor_params[:name].present?

          @horse.ancestors.create!(
            relation_type: ancestor_params[:relation_type],
            name: ancestor_params[:name],
            breeder: ancestor_params[:breeder],
            breed: ancestor_params[:breed]
          )
        end
      end

      render json: @horse.as_json.merge({
        images: @horse.images.map { |image| url_for(image) },
        videos: @horse.videos.map { |video| url_for(video) },
        ancestors: @horse.ancestors
      }), status: :created
    else
      render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Atualiza um cavalo existente
  def update
    ActiveRecord::Base.transaction do
      if @horse.update(horse_params.except(:ancestors_attributes))
        # Atualiza ou cria ancestrais
        if params[:horse][:ancestors_attributes].present?
          # Processar ancestrais enviados
          sent_relation_types = params[:horse][:ancestors_attributes].map { |a| a[:relation_type] }

          # Atualizar ou criar ancestrais
          params[:horse][:ancestors_attributes].each do |ancestor_params|
            ancestor = @horse.ancestors.find_or_initialize_by(relation_type: ancestor_params[:relation_type])
            ancestor.update!(
              name: ancestor_params[:name],
              breeder: ancestor_params[:breeder],
              breed: ancestor_params[:breed]
            )
          end

          # Excluir ancestrais que não estão nos parâmetros enviados
          @horse.ancestors.where.not(relation_type: sent_relation_types).destroy_all
        end

        # Atualizar anexos, se necessário
        purge_images if params[:deleted_images].present?
        purge_videos if params[:deleted_videos].present?
        attach_images(params[:horse][:images]) if params[:horse][:images].present?
        attach_videos(params[:horse][:videos]) if params[:horse][:videos].present?

        render json: @horse.as_json.merge({
          images: @horse.images.map { |img| url_for(img) },
          videos: @horse.videos.map { |vid| url_for(vid) },
          ancestors: @horse.ancestors
        })
      else
        render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end




  # Deleta um cavalo
  def destroy
    @horse.images.purge if @horse.images.attached?
    @horse.videos.purge if @horse.videos.attached?
    @horse.destroy
    head :no_content
  end

  private

  # Função que purga imagens específicas do cavalo
  def purge_images
    return unless params[:deleted_images].present?
    params[:deleted_images].each do |image_url|
      image = @horse.images.find { |img| url_for(img) == image_url }
      image.purge if image
    end
  end

  # Função que purga vídeos específicos do cavalo
  def purge_videos
    params[:deleted_videos].each do |video_url|
      video = @horse.videos.find { |vid| url_for(vid) == video_url }
      video.purge if video
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

  # Função para anexar novos vídeos, evitando duplicações
  def attach_videos(new_videos)
    existing_filenames = @horse.videos.map { |video| video.filename.to_s }

    new_videos.each do |video|
      unless existing_filenames.include?(video.original_filename)
        blob = ActiveStorage::Blob.create_and_upload!(
          io: video.tempfile,
          filename: video.original_filename,
          content_type: video.content_type
        )

        @horse.videos.attach(blob)
      end
    end
  end

  # Encontra o cavalo baseado no ID
  def set_horse
    @horse = current_user.horses.find(params[:id])
  end

  # Permite os parâmetros permitidos para criação e atualização de cavalo
  def horse_params
    params.require(:horse).permit(
      :name, :age, :height_cm, :description, :gender, :color,
      :training_level, :piroplasmosis, images: [], videos: [],
      ancestors_attributes: [:relation_type, :name, :breeder, :breed, :_destroy]
    )
  end
end
