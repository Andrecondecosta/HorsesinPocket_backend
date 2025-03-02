include Rails.application.routes.url_helpers

class Api::V1::HorsesController < ApplicationController
  skip_before_action :authorized, only: [:shared]
  before_action :set_horse, only: [:show, :update, :destroy, :delete_shares, :share_via_link]
  skip_before_action :authorized, only: [:public_test]


  # Lista todos os cavalos do usuário autenticado
  def index
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

  # Exibe um cavalo específico e suas mídias
  def show
    horse = Horse.find(params[:id])
    render json: horse.as_json.merge(
      is_owner: horse.creator == current_user, # Verifica se o criador é o usuário atual
      images: horse.images.map { |image| url_for(image) },
      videos: horse.videos.map { |video| url_for(video) },
      ancestors: horse.ancestors
    )
  end

  # Cria um novo cavalo
  def create
    if current_user.used_horses >= current_user.max_horses
      return render json: { error: "❌ Você atingiu o limite de #{current_user.max_horses} cavalos no plano #{current_user.plan}. Faça upgrade para continuar." }, status: :forbidden
    end

    @horse = current_user.horses.build(horse_params)
    if @horse.save
      Log.create(
            action: 'created',
            horse_name: @horse.name,
            recipient: current_user.name,
            user_id: current_user.id,
            created_at: Time.now
          )
          current_user.increment!(:used_horses)
      process_ancestors(@horse, params[:horse][:ancestors_attributes])

      render json: @horse.as_json.merge({
        images: @horse.images.map { |image| url_for(image) },
        videos: @horse.videos.map { |video| url_for(video) },
        ancestors: @horse.ancestors
      }), status: :created
    else
      render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
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

      # Criar log de edição
      Log.create(
        action: 'updated',
        horse_name: @horse.name,
        recipient: current_user.name,
        user_id: current_user.id,
        created_at: Time.current
      )
    end
  end



  # Deleta um cavalo
  def destroy
    ActiveRecord::Base.transaction do
      if @horse.user_id == current_user.id
        # Criador do cavalo -> Apaga completamente
        Rails.logger.info "Usuário #{current_user.id} é o criador. Deletando completamente o cavalo ID #{@horse.id}."

        # Remove todos os registros associados
        UserHorse.where(horse_id: @horse.id).delete_all
        Ancestor.where(horse_id: @horse.id).delete_all
        SharedLink.where(horse_id: @horse.id).delete_all

        # Remove anexos do ActiveStorage
        @horse.images.purge_later
        @horse.videos.purge_later

        # Apaga o próprio cavalo
        @horse.destroy!

        # Cria log da ação
        Log.create!(
          action: 'deleted',
          horse_name: @horse.name,
          recipient: current_user.name,
          user_id: current_user.id,
          created_at: Time.current
        )

        render json: { message: 'Cavalo deletado para todos, pois você é o criador.' }, status: :ok
      else
        # Usuário apenas remove seu vínculo e os compartilhamentos subsequentes
        Rails.logger.info "Usuário #{current_user.id} NÃO é o criador. Removendo vínculo do cavalo ID #{@horse.id}."

        # Remove a relação do usuário com o cavalo
        UserHorse.where(horse_id: @horse.id, user_id: current_user.id).destroy_all

        # Remove os compartilhamentos subsequentes feitos por esse usuário
        remove_shared_users(current_user.id)

        render json: { message: 'Cavalo removido para você e os usuários subsequentes.' }, status: :ok
      end
    end
  rescue => e
    Rails.logger.error "Erro ao deletar cavalo ou registros associados: #{e.message}"
    render json: { error: 'Erro ao processar a exclusão. Tente novamente.' }, status: :internal_server_error
  end



  def delete_shares
    ActiveRecord::Base.transaction do
      shared_users = User.joins(:user_horses)
                         .where(user_horses: { horse_id: @horse.id, shared_by: current_user.id })
                         .where.not(id: current_user.id)

      Rails.logger.info "Registros na tabela user_horses para horse_id=#{@horse.id}, shared_by=#{current_user.id}:"
      Rails.logger.info UserHorse.where(horse_id: @horse.id, shared_by: current_user.id).pluck(:id, :user_id, :shared_by)

      Rails.logger.info "Usuários compartilhados diretamente pelo usuário #{current_user.id}: #{shared_users.map(&:id)}"

      shared_users.each do |user|
        create_log(
          action: 'deleted_share',
          horse_name: @horse.name,
          recipient: user.name,
        )
        UserHorse.where(horse_id: @horse.id, user_id: user.id).destroy_all
        remove_shared_users(user.id)
      end
    end

    render json: { message: 'Compartilhamentos subsequentes removidos com sucesso.' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Erro ao remover compartilhamentos: #{e.message}"
    render json: { error: 'Erro ao remover compartilhamentos subsequentes.' }, status: :internal_server_error
  end



  def share_via_link
    if current_user.used_shares.to_i >= current_user.max_shares.to_i
      return render json: { error: "❌ Você atingiu o limite de #{current_user.max_shares} partilhas no plano #{current_user.plan}. Faça upgrade para continuar." }, status: :forbidden
    end

    Rails.logger.info "🚀 Iniciando compartilhamento do cavalo com ID: #{@horse.id}"

    ActiveRecord::Base.transaction do
      # 🔒 Bloqueia a linha no banco de dados antes de verificar o link existente
      recent_link = SharedLink.where(horse_id: @horse.id, shared_by: current_user.id)
                              .where("created_at >= ?", 2.seconds.ago)
                              .order(created_at: :desc)
                              .limit(1)
                              .lock("FOR UPDATE SKIP LOCKED") # 🔒 Evita concorrência

      if recent_link.exists?
        Rails.logger.info "⏳ Link recente encontrado: #{recent_link.first.token}. Usando esse link."
        return render json: { link: "#{Rails.application.routes.default_url_options[:host]}/horses/shared/#{recent_link.first.token}" }, status: :ok
      end

      # 🔹 Criar novo link se não existir um recente
      shared_link = @horse.shared_links.create!(
        token: SecureRandom.urlsafe_base64(10),
        expires_at: params[:expires_at],
        status: 'active',
        shared_by: current_user.id
      )

      Rails.logger.info "✅ Novo link criado: #{shared_link.token}"

    # 🔹 Verifica se o último log foi criado há menos de 2 segundos
    existing_log = Log.where(action: 'shared_via_link', horse_name: @horse.name, user_id: current_user.id)
                      .where("recipient LIKE ?", "Pending%")
                      .order(created_at: :desc)
                      .first

    if existing_log && existing_log.created_at >= 2.seconds.ago
      Rails.logger.info "⏳ Log 'shared_via_link' já foi criado há menos de 2 segundos. Bloqueando duplicação."
    else
      new_log = create_log(
        action: 'shared_via_link',
        horse_name: @horse.name,
        recipient: "Pending - Will be assigned when used"
      )
      Rails.logger.info "✅ Novo log criado com ID #{new_log.id} e recipient: #{new_log.recipient}"
    end

      current_user.increment!(:used_shares)

      # 🔹 Garante que o cavalo está associado ao usuário
      user_horse = UserHorse.find_or_initialize_by(horse_id: @horse.id, user_id: current_user.id)
      user_horse.shared_by ||= current_user.id
      user_horse.save!

      Rails.logger.info "✅ Cavalo associado ao usuário com sucesso."

      render json: { link: "#{Rails.application.routes.default_url_options[:host]}/horses/shared/#{shared_link.token}" }, status: :created
    end
  rescue => e
    Rails.logger.error "❌ Erro ao criar link de compartilhamento: #{e.message}"
    render json: { error: 'Erro ao criar link de compartilhamento. Tente novamente.' }, status: :internal_server_error
  end


 # Exemplo de Backend (Controller)
 def shared
  Rails.logger.info "🟢 Starting sharing request with token: #{params[:token]}"

  shared_link = SharedLink.find_by(token: params[:token])

  if shared_link.nil?
    Rails.logger.error "❌ Sharing link not found for token: #{params[:token]}"
    return render json: { error: 'Sharing link not found' }, status: :not_found
  end

  Rails.logger.info "✅ Sharing link found: #{shared_link.inspect}"

  unless current_user
    Rails.logger.error "❌ No authenticated user found! Redirecting to login."
    return render json: { error: '⚠️ You need to log in to claim this horse.', redirect: '/welcome' }, status: :unauthorized
  end

  if shared_link.status == 'used'
    Rails.logger.info "⚠️ Link has already been used and is inactive."
    return render json: { error: '⚠️ This link has already been used or expired.' }, status: :forbidden
  end

  ActiveRecord::Base.transaction do
    Rails.logger.info "🔄 Associating horse ID #{shared_link.horse_id} with user #{current_user.id}"

    user_horse = UserHorse.find_or_initialize_by(horse_id: shared_link.horse_id, user_id: current_user.id)

    if user_horse.persisted?
      Rails.logger.info "✅ User #{current_user.id} has already received horse ID #{shared_link.horse_id}. No action necessary."
    else
      sender_user = User.find_by(id: shared_link.shared_by)
      sender_name = sender_user ? sender_user.name : "Unknown"
      recipient_name = current_user.name

      user_horse.shared_by = shared_link.shared_by || shared_link.horse.user_id
      user_horse.save!
      Rails.logger.info "✅ Horse ID #{shared_link.horse_id} successfully added to user #{current_user.id}."

      # 🔹 Atualizar o log "shared_via_link" para o nome do destinatário correto
      log_to_update = Log.where(action: 'shared_via_link', horse_name: user_horse.horse.name, user_id: shared_link.shared_by)
                         .where("recipient LIKE ?", "Pending%")
                         .order(created_at: :desc)
                         .limit(1)
                         .lock("FOR UPDATE SKIP LOCKED") # 🔒 Evita concorrência
                         .first

      if log_to_update
        Rails.logger.info "📝 Atualizando log 'shared_via_link' de 'Pending' para '#{recipient_name}'"
        log_to_update.update!(recipient: recipient_name)
        Rails.logger.info "✅ Log atualizado com sucesso: #{log_to_update.inspect}"
      else
        Rails.logger.warn "⚠️ Nenhum log 'shared_via_link' encontrado para atualizar!"
      end

      # 🔹 Criar um novo log indicando que o cavalo foi recebido
      begin
        Rails.logger.info "🔹 Criando log de 'received' para #{recipient_name}, enviado por #{sender_name}"
        create_log(action: 'received', horse_name: user_horse.horse.name, recipient: sender_name)
        Rails.logger.info "✅ Log de 'received' criado com sucesso!"
      rescue => log_error
        Rails.logger.error "❌ Erro ao criar log de 'received': #{log_error.message}"
      end

      shared_link.update!(used_at: Time.current, status: 'used')
      Rails.logger.info "🔒 Sharing link marked as 'used'."
    end
  end

  render json: { message: '✅ Horse successfully added to received.' }, status: :ok
rescue => e
  Rails.logger.error "❌ Error processing the sharing link: #{e.message}"
  render json: { error: 'Error processing the sharing link. Please try again.' }, status: :internal_server_error
end

def received_horses
  @received_horses = Horse.joins(:user_horses)
                          .where(user_horses: { user_id: current_user.id })
                          .where.not(user_id: current_user.id) # 🔹 Evita listar os próprios cavalos
                          .distinct

  render json: @received_horses.map { |horse|
    # 🔹 Pegamos a última transferência para ver quem compartilhou com o usuário atual
    last_transfer = UserHorse.where(horse_id: horse.id, user_id: current_user.id)
                             .order(created_at: :desc)
                             .first

    sender_user = last_transfer ? User.find_by(id: last_transfer.shared_by) : nil

    horse.as_json.merge({
      images: horse.images.map { |image| url_for(image) },
      sender_name: sender_user&.name || 'Desconhecido'
    })
  }
end

  def public_test
    render json: { message: "Public test endpoint" }
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
      :training_level, :breed, :breeder, :piroplasmosis, images: [], videos: [],
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

  def remove_shared_users(shared_by)
    # Busca usuários subsequentes que receberam o cavalo de `shared_by`
    shared_users = User.joins(:user_horses)
                       .where(user_horses: { horse_id: @horse.id, shared_by: shared_by })

    Rails.logger.info "Usuários subsequentes encontrados para shared_by #{shared_by}: #{shared_users.map(&:id)}"

    shared_users.each do |user|
      Rails.logger.info "Removendo vínculo subsequente de #{user.name} (User ID: #{user.id})"

      # Remove o vínculo
      UserHorse.where(horse_id: @horse.id, user_id: user.id).destroy_all

      # Recursivamente remove compartilhamentos subsequentes
      remove_shared_users(user.id)
    end
  end

  end
