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
    logs = []
    begin
      # Log dos parâmetros recebidos
      logs << "Parâmetros recebidos: #{params.inspect}"

      # Criação do cavalo associado ao utilizador atual
      @horse = current_user.horses.build(horse_params)
      logs << "Cavalo criado (não salvo): #{@horse.inspect}"

      if @horse.save
        logs << "Cavalo salvo com sucesso: #{@horse.id}"

        if params[:horse][:ancestors_attributes].is_a?(Array)
          params[:horse][:ancestors_attributes].each do |ancestor_params|
            if ancestor_params.is_a?(Hash) && ancestor_params[:relation_type].present? && ancestor_params[:name].present?
              # Verifica se já existe um ancestral com o mesmo relation_type
              existing_ancestor = @horse.ancestors.find_by(relation_type: ancestor_params[:relation_type])

              if existing_ancestor
                logs << "Já existe um ancestral com relation_type #{ancestor_params[:relation_type]}. Atualizando os dados."
                existing_ancestor.update(
                  name: ancestor_params[:name],
                  breeder: ancestor_params[:breeder],
                  breed: ancestor_params[:breed]
                )
              else
                logs << "Criando novo ancestral: #{ancestor_params.inspect}"
                @horse.ancestors.create!(
                  relation_type: ancestor_params[:relation_type],
                  name: ancestor_params[:name],
                  breeder: ancestor_params[:breeder],
                  breed: ancestor_params[:breed]
                )
              end
            else
              logs << "Ancestral ignorado por falta de dados: #{ancestor_params.inspect}"
            end
          end
        else
          logs << "Nenhum ancestral recebido."
        end

        # Processa imagens, se existirem
        if params[:horse][:images].present?
          params[:horse][:images].each do |image|
            begin
              logs << "Anexando imagem: #{image.original_filename}"
              @horse.images.attach(image)
            rescue => e
              logs << "Erro ao anexar imagem #{image.original_filename}: #{e.message}"
            end
          end
        else
          logs << "Nenhuma imagem recebida."
        end

        # Processa vídeos, se existirem
        if params[:horse][:videos].present?
          params[:horse][:videos].each do |video|
            begin
              logs << "Anexando vídeo: #{video.original_filename}"
              @horse.videos.attach(video)
            rescue => e
              logs << "Erro ao anexar vídeo #{video.original_filename}: #{e.message}"
            end
          end
        else
          logs << "Nenhum vídeo recebido."
        end

        # Retorna o cavalo criado com logs para debug
        render json: {
          horse: @horse.as_json.merge({
            images: @horse.images.map { |image| url_for(image) },
            videos: @horse.videos.map { |video| url_for(video) },
            ancestors: @horse.ancestors
          }),
          logs: logs
        }, status: :created
      else
        logs << "Erro ao salvar cavalo: #{@horse.errors.full_messages}"
        render json: { errors: @horse.errors.full_messages, logs: logs }, status: :unprocessable_entity
      end

    rescue => e
      # Captura erros inesperados
      logs << "Erro inesperado: #{e.message}"
      logs << "Backtrace: #{e.backtrace.take(10).join("\n")}"
      render json: { error: "Erro interno do servidor.", logs: logs }, status: :internal_server_error
    end
  end


  # Atualiza um cavalo existente
  def update
    ActiveRecord::Base.transaction do
      if @horse.update(horse_params.except(:ancestors_attributes, :images, :videos))
        process_ancestors(@horse, params[:horse][:ancestors_attributes]) if params[:horse][:ancestors_attributes].present?
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
      ActiveRecord::Base.transaction do
        @horse.destroy
        create_log(action: 'deleted', horse_name: @horse.name)
      end
      render json: { message: 'Cavalo deletado para todos, pois você é o criador.' }, status: :ok
    else
      UserHorse.where(horse_id: @horse.id, user_id: current_user.id).destroy_all
      render json: { message: 'Cavalo removido da sua lista.' }, status: :ok
    end
  end

  # Compartilha um cavalo com outro usuário
  def share
    recipient = User.find_by(email: params[:email])

    if recipient.nil?
      UserMailer.invite_new_user(current_user, params[:email], @horse).deliver_now
      render json: { message: "Convite enviado para #{params[:email]}!" }, status: :ok
    else
      if @horse.users.include?(recipient)
        render json: { error: 'Cavalo já compartilhado com este usuário' }, status: :unprocessable_entity
      else
        @horse.users << recipient
        UserMailer.share_horse_email(current_user, recipient.email, @horse).deliver_later
        create_log(action: 'shared', horse_name: @horse.name, recipient: recipient.email)
        render json: { message: "Cavalo compartilhado com sucesso com #{recipient.email}!" }, status: :ok
      end
    end
  end

  def received_horses
    @received_horses = Horse.joins(:user_horses).where(user_horses: { user_id: current_user.id })

    render json: @received_horses.map { |horse|
      last_transfer_to_current_user = UserHorse.where(horse_id: horse.id, user_id: current_user.id).order(created_at: :desc).first
      sender = User.find(last_transfer_to_current_user.shared_by) if last_transfer_to_current_user&.shared_by
      horse.as_json.merge({
        images: horse.images.map { |image| url_for(image) },
        sender_name: sender&.name || 'Desconhecido'
      })
    }
  end

  private

  def purge_images
    params[:deleted_images].each do |url|
      @horse.images.each { |img| img.purge if url_for(img) == url }
    end
  end

  def purge_videos
    params[:deleted_videos].each do |url|
      @horse.videos.each { |vid| vid.purge if url_for(vid) == url }
    end
  end

  def attach_images(images)
    images.each { |img| @horse.images.attach(img) unless @horse.images.map(&:filename).include?(img.original_filename) }
  end

  def attach_videos(videos)
    videos.each do |vid|
      blob = ActiveStorage::Blob.create_and_upload!(io: vid.tempfile, filename: vid.original_filename, content_type: vid.content_type)
      @horse.videos.attach(blob)
    end
  end

  def process_ancestors(horse, ancestors_attributes)
    ancestors_attributes.each do |ancestor_params|
      horse.ancestors.find_or_create_by(relation_type: ancestor_params[:relation_type]).update!(ancestor_params)
    end
  end

  def horse_params
    params.require(:horse).permit(:name, :age, :height_cm, :description, :gender, :color, :training_level, :piroplasmosis, images: [], videos: [], ancestors_attributes: [:relation_type, :name, :breeder, :breed])
  end

  def set_horse
    @horse = Horse.find_by(id: params[:id])
    render json: { error: 'Cavalo não encontrado ou você não tem permissão para acessá-lo.' }, status: :not_found unless @horse
  end

  def create_log(action:, horse_name:, recipient: nil)
    Log.create(action: action, horse_name: horse_name, recipient: recipient || 'N/A', user_id: current_user.id)
  end
end
