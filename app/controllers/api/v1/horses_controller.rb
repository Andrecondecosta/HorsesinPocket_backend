class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy, :share]
  before_action :authorized

  # Lista todos os cavalos do usuário autenticado
  def index
    begin
      @horses = current_user.horses.includes(:ancestors, images_attachments: :blob, videos_attachments: :blob)
      render json: @horses.map { |horse|
        horse.as_json.merge({
          images: horse.images.map { |image| url_for(image) },
          videos: horse.videos.map { |video| url_for(video) },
          ancestors: horse.ancestors
        })
      }, status: :ok
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
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
    Rails.logger.info("Parâmetros recebidos no método create: #{params.inspect}")

    begin
      # Criação do cavalo
      @horse = current_user.horses.build(horse_params)
      Rails.logger.info("Cavalo criado: #{@horse.inspect}")

      # Salvar o cavalo
      if @horse.save
        Rails.logger.info("Cavalo salvo com sucesso: #{@horse.id}")

        # Processa imagens
        if params[:horse][:images]
          params[:horse][:images].each do |image|
            Rails.logger.info("Anexando imagem: #{image.original_filename}")
            @horse.images.attach(image)
          end
          Rails.logger.info("Imagens anexadas com sucesso.")
        end

        # Processa vídeos
        if params[:horse][:videos]
          params[:horse][:videos].each do |video|
            Rails.logger.info("Anexando vídeo: #{video.original_filename}")
            @horse.videos.attach(video)
          end
          Rails.logger.info("Vídeos anexados com sucesso.")
        end

        # Resposta de sucesso
        render json: @horse.as_json.merge({
          images: @horse.images.map { |image| url_for(image) },
          videos: @horse.videos.map { |video| url_for(video) },
          ancestors: @horse.ancestors
        }), status: :created
      else
        Rails.logger.error("Erro ao salvar cavalo: #{@horse.errors.full_messages}")
        render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
      end

    rescue => e
      # Captura e loga erros inesperados
      Rails.logger.error("Erro inesperado no método create: #{e.message}")
      Rails.logger.error("Backtrace:\n#{e.backtrace.join("\n")}")
      render json: { error: "Erro interno do servidor." }, status: :internal_server_error
    end
  end



  def update
    ActiveRecord::Base.transaction do
      if @horse.update(horse_params.except(:ancestors_attributes, :images, :videos))
        # Processa os ancestrais, se aplicável
        process_ancestors(@horse, params[:horse][:ancestors_attributes])

        # Purga apenas as imagens e vídeos explicitamente deletados
        purge_images if params[:deleted_images].present?
        purge_videos if params[:deleted_videos].present?

        # Adiciona novas imagens sem ultrapassar o limite
        if params[:horse][:images].present?
          total_images = @horse.images.count + params[:horse][:images].size
          if total_images <= 5
            attach_images(params[:horse][:images])
          else
            render json: { error: "Você pode adicionar no máximo 5 imagens. Atualmente, o cavalo tem #{total_images - params[:horse][:images].size} imagens." }, status: :unprocessable_entity
            return
          end
        end

        # Adiciona novos vídeos sem ultrapassar o limite
        if params[:horse][:videos].present?
          total_videos = @horse.videos.count + params[:horse][:videos].size
          if total_videos <= 3
            attach_videos(params[:horse][:videos])
          else
            render json: { error: "Você pode adicionar no máximo 3 vídeos. Atualmente, o cavalo tem #{total_videos - params[:horse][:videos].size} vídeos." }, status: :unprocessable_entity
            return
          end
        end

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

        Log.create(
        action: 'deleted',
        horse_name: @horse.name,
        recipient: 'N/A',
        user_id: current_user.id,
        created_at: Time.now
      )
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
      UserMailer.invite_new_user(current_user, params[:email], @horse).deliver_now
      render json: { message: "Convite enviado para #{params[:email]}!" }, status: :ok
    else
      # Compartilhar com usuário existente
      if @horse.users.include?(recipient)
        render json: { error: 'Cavalo já compartilhado com este usuário' }, status: :unprocessable_entity
      else
        @horse.users << recipient
        UserMailer.share_horse_email(current_user, recipient.email, @horse).deliver_later
        render json: { message: "Cavalo compartilhado com sucesso com #{recipient.email}!" }, status: :ok

        # Criar log da ação de compartilhamento
      Log.create(
        action: 'shared',
        horse_name: @horse.name,
        recipient: recipient.email,
        user_id: current_user.id,
        created_at: Time.now
      )

      Log.create(
        action: 'received',
        horse_name: @horse.name,
        recipient: current_user.email,
        user_id: recipient.id,
        created_at: Time.now
      )

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

    Rails.logger.debug "Imagens para remover: #{params[:deleted_images]}"

    @horse.images.each do |image|
      Rails.logger.debug "Verificando imagem: #{url_for(image)}"
      if params[:deleted_images].include?(url_for(image))
        Rails.logger.debug "Removendo imagem: #{url_for(image)}"
        image.purge
      end
    end
  end




  # Função que purga vídeos específicos do cavalo
  def purge_videos
    return unless params[:deleted_videos].present?

    params[:deleted_videos].each do |video_url|
      # Procura o vídeo correspondente no ActiveStorage
      video = @horse.videos.find do |vid|
        begin
          url_for(vid) == video_url
        rescue => e
          Rails.logger.error "Erro ao verificar vídeo para exclusão: #{e.message}"
          nil
        end
      end

      if video
        Rails.logger.debug "Removendo vídeo: #{url_for(video)}"
        video.purge
      else
        Rails.logger.debug "Vídeo não encontrado: #{video_url}"
      end
    end
  end




  # Função para anexar novas imagens, evitando duplicações
  def attach_images(new_images)
    return unless new_images.present?

    new_images.each do |image|
      # Verifica se a imagem já está anexada para evitar duplicação
      unless @horse.images.map(&:filename).include?(image.original_filename)
        Rails.logger.debug "Anexando imagem: #{image.original_filename}"
        @horse.images.attach(image)
      else
        Rails.logger.debug "Imagem já anexada: #{image.original_filename}"
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

  def create_log(action:, horse_name:, recipient: nil)
    Log.create(
      action: action,
      horse_name: horse_name,
      recipient: recipient || 'N/A',
      user_id: current_user.id,
      created_at: Time.now
    )
  end

  def process_ancestors(horse, ancestors_attributes)
    return unless ancestors_attributes.present?

    sent_relation_types = ancestors_attributes.map { |a| a[:relation_type] }

    ancestors_attributes.each do |ancestor_params|
      ancestor = horse.ancestors.find_or_initialize_by(relation_type: ancestor_params[:relation_type])
      ancestor.update!(
        name: ancestor_params[:name],
        breeder: ancestor_params[:breeder],
        breed: ancestor_params[:breed]
      )
    end

    horse.ancestors.where.not(relation_type: sent_relation_types).destroy_all
  end
end
