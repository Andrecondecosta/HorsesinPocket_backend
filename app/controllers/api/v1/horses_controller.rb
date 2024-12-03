class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy, :share]

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
    @horse.user_id = current_user.id

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
    if @horse.user_id == current_user.id
      # Criador apaga o cavalo: remove para todos
      ActiveRecord::Base.transaction do
        @horse.destroy
      end
      render json: { message: 'Cavalo deletado para todos, pois você é o criador.' }, status: :ok
    else
      # Remover o vínculo do usuário atual e de todos subsequentes
      shared_users = User.joins(:user_horses)
                         .where(user_horses: { horse_id: @horse.id, shared_by: current_user.id })

      # Remove o vínculo do usuário atual
      UserHorse.where(horse_id: @horse.id, user_id: current_user.id).destroy_all

      # Propagar exclusão para todos subsequentes
      shared_users.each do |user|
        UserHorse.where(horse_id: @horse.id, user_id: user.id).destroy_all
      end

      render json: { message: 'Cavalo removido da sua lista e dos usuários subsequentes.' }, status: :ok
    end
  end


  # Compartilha um cavalo com outro usuário
 # app/controllers/api/v1/horses_controller.rb

  # Compartilhar cavalo com outro usuário
  def share
    recipient = User.find_by(email: params[:email])

    if recipient.nil?
      # Enviar convite para novo usuário
      UserMailer.invite_new_user(current_user, params[:email], @horse).deliver_later
      render json: { message: "Convite enviado para #{params[:email]}!" }, status: :ok
    else
      # Compartilhar com usuário existente
      if @horse.users.include?(recipient)
        render json: { error: 'Cavalo já compartilhado com este usuário' }, status: :unprocessable_entity
      else
        @horse.users << recipient
        UserMailer.share_horse_email(current_user, recipient.email, @horse).deliver_later
        render json: { message: "Cavalo compartilhado com sucesso com #{recipient.email}!" }, status: :ok
      end
    end
  end



def received_horses
  @received_horses = Horse.joins(:user_horses)
                          .where(user_horses: { user_id: current_user.id })

  render json: @received_horses.map { |horse|
    # Encontra a última transferência para o usuário atual
    last_transfer_to_current_user = UserHorse.where(horse_id: horse.id, user_id: current_user.id)
                                             .order(created_at: :desc)
                                             .first

    # Encontra o remetente da última transferência para o usuário atual
    sender = if last_transfer_to_current_user
               UserHorse.where(horse_id: horse.id)
                        .where('created_at < ?', last_transfer_to_current_user.created_at)
                        .order(created_at: :desc)
                        .first
             end

    sender_user = sender ? User.find(sender.user_id) : nil

    # Prioriza o remetente e, caso não exista, exibe o nome do criador
    horse.as_json.merge({
      images: horse.images.map { |image| url_for(image) },
      sender_name: sender_user&.name || horse.creator&.name || 'Desconhecido'
    })
  }
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
    @horse = Horse
            .left_joins(:user_horses)
            .where('(horses.user_id = :user_id OR user_horses.user_id = :user_id)', user_id: current_user.id)
            .find_by(id: params[:id])

    unless @horse
      render json: { error: "Cavalo não encontrado ou você não tem permissão para acessá-lo." }, status: :not_found
    end
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
