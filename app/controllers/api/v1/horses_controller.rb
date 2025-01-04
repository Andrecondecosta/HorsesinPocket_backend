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
    begin
      @horse = current_user.horses.build(horse_params)

      if @horse.save
        process_ancestors(@horse, params[:horse][:ancestors_attributes]) if params[:horse][:ancestors_attributes].present?
        attach_images(params[:horse][:images]) if params[:horse][:images].present?
        attach_videos(params[:horse][:videos]) if params[:horse][:videos].present?

        render json: @horse.as_json.merge({
          images: @horse.images.map { |image| url_for(image) },
          videos: @horse.videos.map { |video| url_for(video) },
          ancestors: @horse.ancestors
        }), status: :created
      else
        render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      render json: { error: "Erro interno do servidor: #{e.message}" }, status: :internal_server_error
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
