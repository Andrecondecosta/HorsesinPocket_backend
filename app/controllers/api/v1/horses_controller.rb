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
      is_owner: horse.creator == current_user,
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
        Rails.logger.info "Usuário #{current_user.id} é o criador. Deletando completamente o cavalo ID #{@horse.id}."

        UserHorse.where(horse_id: @horse.id).delete_all
        Ancestor.where(horse_id: @horse.id).delete_all
        SharedLink.where(horse_id: @horse.id).delete_all

        @horse.images.purge_later
        @horse.videos.purge_later

        @horse.destroy!

        Log.create!(
          action: 'deleted',
          horse_name: @horse.name,
          recipient: current_user.name,
          user_id: current_user.id,
          created_at: Time.current
        )

        render json: { message: 'Cavalo deletado para todos, pois você é o criador.' }, status: :ok
      else
        Rails.logger.info "Usuário #{current_user.id} NÃO é o criador. Removendo vínculo do cavalo ID #{@horse.id}."

        UserHorse.where(horse_id: @horse.id, user_id: current_user.id).destroy_all

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
                         .where(id: params[:user_ids])

      Rails.logger.info "🔍 Registros antes da remoção para horse_id=#{@horse.id}, shared_by=#{current_user.id}:"
      Rails.logger.info UserHorse.where(horse_id: @horse.id, shared_by: current_user.id).pluck(:id, :user_id, :shared_by)

      Rails.logger.info "🧑‍🤝‍🧑 Usuários que receberam o cavalo do usuário #{current_user.id}: #{shared_users.map(&:id)}"

      shared_users.each do |user|
        create_log(
          action: 'deleted_share',
          horse_name: @horse.name,
          recipient: user.name
        )

        removed_shares = UserHorse.where(horse_id: @horse.id, user_id: user.id, shared_by: current_user.id)

        if removed_shares.exists?
          removed_shares.destroy_all
          Rails.logger.info "✅ Partilha removida para usuário #{user.id} pelo usuário #{current_user.id}"
        else
          Rails.logger.warn "⚠️ Nenhuma partilha encontrada para usuário #{user.id} compartilhada por #{current_user.id}"
        end

        if UserHorse.where(horse_id: @horse.id, user_id: user.id).exists?
          Rails.logger.info "🔄 Usuário #{user.id} ainda tem acesso ao cavalo, não removendo partilhas subsequentes."
        else
          remove_shared_users(user.id)
        end
      end
    end

    render json: { message: 'Partilha removida com sucesso.' }, status: :ok
  rescue StandardError => e
    Rails.logger.error "❌ Erro ao remover partilha: #{e.message}"
    render json: { error: 'Erro ao remover partilha.' }, status: :internal_server_error
  end



  def share_via_link
    if current_user.used_shares.to_i >= current_user.max_shares.to_i
      return render json: { error: "❌ Você atingiu o limite de #{current_user.max_shares} partilhas no plano #{current_user.plan}. Faça upgrade para continuar." }, status: :forbidden
    end

    Rails.logger.info "🚀 Iniciando compartilhamento do cavalo com ID: #{@horse.id}"

    ActiveRecord::Base.transaction do
      recent_link = SharedLink.where(horse_id: @horse.id, shared_by: current_user.id)
                              .where("created_at >= ?", 2.seconds.ago)
                              .order(created_at: :desc)
                              .limit(1)
                              .lock("FOR UPDATE SKIP LOCKED")

      if recent_link.exists?
        Rails.logger.info "⏳ Link recente encontrado: #{recent_link.first.token}. Usando esse link."
        return render json: { link: "#{Rails.application.routes.default_url_options[:host]}/horses/shared/#{recent_link.first.token}" }, status: :ok
      end

      shared_link = @horse.shared_links.create!(
        token: SecureRandom.urlsafe_base64(10),
        expires_at: params[:expires_at],
        status: 'active',
        shared_by: current_user.id
      )

      Rails.logger.info "✅ Novo link criado: #{shared_link.token}"

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
      sender_name = sender_user ? "#{sender_user.first_name} #{sender_user.last_name}".strip : "Unknown"
      recipient_name = "#{current_user.first_name} #{current_user.last_name}".strip

      user_horse.shared_by = shared_link.shared_by || shared_link.horse.user_id
      user_horse.save!
      Rails.logger.info "✅ Horse ID #{shared_link.horse_id} successfully added to user #{current_user.id}."

      log_to_update = Log.where(action: 'shared_via_link', horse_name: user_horse.horse.name, user_id: shared_link.shared_by)
                         .where("recipient LIKE ?", "Pending%")
                         .order(created_at: :desc)
                         .limit(1)
                         .lock("FOR UPDATE SKIP LOCKED")
                         .first

      if log_to_update
        Rails.logger.info "📝 Atualizando log 'shared_via_link' de 'Pending' para '#{recipient_name}'"
        log_to_update.update!(recipient: recipient_name)
        Rails.logger.info "✅ Log atualizado com sucesso: #{log_to_update.inspect}"
      else
        Rails.logger.warn "⚠️ Nenhum log 'shared_via_link' encontrado para atualizar!"
      end

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
                          .where.not(user_id: current_user.id)
                          .distinct

  render json: @received_horses.map { |horse|
    user_horse = UserHorse.where(horse_id: horse.id, user_id: current_user.id)
                          .order(created_at: :desc)
                          .first

    sender_user = user_horse ? User.find_by(id: user_horse.shared_by) : nil

    horse.as_json.merge({
      images: horse.images.map { |image| url_for(image) },
      sender_name: sender_user&.name || 'Desconhecido',
      status: user_horse&.status || 'active'
    })
  }
end

  def pending_approvals
    horse = Horse.find_by(id: params[:id])

    unless horse
      return render json: { error: "Horse not found" }, status: :not_found
    end

    unless horse.user_id == current_user.id
      return render json: { error: "Not authorized" }, status: :unauthorized
    end

    pending = UserHorse.includes(:user)
                       .where(horse_id: horse.id, status: 'pending_approval')
                       .where.not(user_id: current_user.id)

    render json: {
      pending_approvals: pending.map { |uh|
        {
          user_horse_id: uh.id,
          user_name: "#{uh.user.first_name} #{uh.user.last_name}".strip
        }
      }
    }
  end

  def shares
    @horse = Horse.find_by(id: params[:id])

    unless @horse
      return render json: { error: "Cavalo não encontrado" }, status: :not_found
    end

    shared_users = User.joins(:user_horses)
                      .where(user_horses: { horse_id: @horse.id, shared_by: current_user.id })
                      .where.not(id: current_user.id)
                      .select("users.id, users.first_name, users.last_name")

    render json: { shares: shared_users.map { |user|
      {
        user_id: user.id,
        user_name: "#{user.first_name} #{user.last_name}".strip
      }
    }}
  end




  def public_test
    render json: { message: "Public test endpoint" }
  end


  private

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




  def purge_videos
    return unless params[:deleted_videos].present?

    params[:deleted_videos].each do |video_url|
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




  def attach_images(new_images)
    return unless new_images.present?

    new_images.each do |image|
      unless @horse.images.map(&:filename).include?(image.original_filename)
        Rails.logger.debug "Anexando imagem: #{image.original_filename}"
        @horse.images.attach(image)
      else
        Rails.logger.debug "Imagem já anexada: #{image.original_filename}"
      end
    end
  end



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


  def set_horse
    @horse = Horse
            .left_joins(:user_horses)
            .where('(horses.user_id = :user_id OR user_horses.user_id = :user_id)', user_id: current_user.id)
            .find_by(id: params[:id])

    unless @horse
      render json: { error: "Cavalo não encontrado ou você não tem permissão para acessá-lo." }, status: :not_found
    end
  end

  # CHANGED: Added :id to ancestors_attributes so existing ancestors are found by ID
  def horse_params
    params.require(:horse).permit(
      :name, :age, :height_cm, :description, :gender, :color,
      :training_level, :breed, :breeder, :piroplasmosis, images: [], videos: [],
      ancestors_attributes: [:id, :relation_type, :name, :breeder, :breed, :_destroy]
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

  # CHANGED: Now looks up ancestors by :id first (when available) to correctly
  # update existing records in-place, avoiding uniqueness validation conflicts.
  def process_ancestors(horse, ancestors_attributes)
    return unless ancestors_attributes.present?

    sent_relation_types = ancestors_attributes.map { |a| a[:relation_type] || a["relation_type"] }.compact

    ancestors_attributes.each do |ancestor_params|
      ancestor_id      = ancestor_params[:id]            || ancestor_params["id"]
      relation_type    = ancestor_params[:relation_type] || ancestor_params["relation_type"]
      ancestor_name    = ancestor_params[:name]          || ancestor_params["name"]
      ancestor_breed   = ancestor_params[:breed]         || ancestor_params["breed"]
      ancestor_breeder = ancestor_params[:breeder]       || ancestor_params["breeder"]

      # Look up by ID first so existing records are updated in-place
      # (avoids uniqueness validation conflict on relation_type)
      ancestor = nil
      ancestor = horse.ancestors.find_by(id: ancestor_id) if ancestor_id.present?
      ancestor ||= horse.ancestors.find_or_initialize_by(relation_type: relation_type)

      ancestor.update!(
        relation_type: relation_type,
        name: ancestor_name,
        breeder: ancestor_breeder,
        breed: ancestor_breed
      )
    end

    horse.ancestors.where.not(relation_type: sent_relation_types).destroy_all
  end

  def remove_shared_users(shared_by)
    shared_users = User.joins(:user_horses)
                       .where(user_horses: { horse_id: @horse.id, shared_by: shared_by })

    Rails.logger.info "Usuários subsequentes encontrados para shared_by #{shared_by}: #{shared_users.map(&:id)}"

    shared_users.each do |user|
      Rails.logger.info "Removendo vínculo subsequente de #{user.name} (User ID: #{user.id})"

      UserHorse.where(horse_id: @horse.id, user_id: user.id).destroy_all

      remove_shared_users(user.id)
    end
  end

end
