class Api::V1::HorsesController < ApplicationController
  before_action :set_horse, only: [:show, :update, :destroy, :delete_shares, :share_via_link]
  skip_before_action :authorized, only: [:shared]

  # GET /horses
  def index
    horses = current_user.horses.map do |horse|
      {
        id: horse.id,
        name: horse.name,
        age: horse.age,
        gender: horse.gender,
        color: horse.color,
        height_cm: horse.height_cm,
        images: horse.images.map { |image| url_for(image) },
        is_owner: horse.user_id == current_user.id
      }
    end
    render json: horses, status: :ok
  end

  # GET /horses/:id
  def show
    render json: {
      id: @horse.id,
      name: @horse.name,
      age: @horse.age,
      gender: @horse.gender,
      color: @horse.color,
      height_cm: @horse.height_cm,
      piroplasmosis: @horse.piroplasmosis,
      breed: @horse.breed,
      breeder: @horse.breeder,
      training_level: @horse.training_level,
      description: @horse.description,
      images: @horse.images.map { |image| url_for(image) },
      videos: @horse.videos.map { |video| url_for(video) },
      ancestors: @horse.ancestors,
      is_owner: @horse.user_id == current_user.id,
      status: UserHorse.find_by(horse_id: @horse.id, user_id: current_user.id)&.status
    }, status: :ok
  end

  # POST /horses
  def create
    horse = Horse.new(horse_params)
    horse.user_id = current_user.id

    if horse.save
      UserHorse.create!(horse_id: horse.id, user_id: current_user.id, shared_by: current_user.id)

      Log.create!(
        action: 'created',
        horse_name: horse.name,
        recipient: "#{current_user.first_name} #{current_user.last_name}",
        user_id: current_user.id,
        created_at: Time.current
      )

      render json: { id: horse.id, message: "Horse created successfully" }, status: :created
    else
      render json: { errors: horse.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /horses/:id
  def update
    if @horse.update(horse_params)
      create_log(action: 'updated', horse_name: @horse.name, recipient: "#{current_user.first_name} #{current_user.last_name}")
      render json: { message: "Horse updated successfully" }, status: :ok
    else
      render json: { errors: @horse.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /horses/:id
  def destroy
    user_horse = UserHorse.find_by(horse_id: @horse.id, user_id: current_user.id)

    unless user_horse
      return render json: { error: "Not authorized" }, status: :unauthorized
    end

    if @horse.user_id == current_user.id
      create_log(action: 'deleted', horse_name: @horse.name, recipient: "#{current_user.first_name} #{current_user.last_name}")
      @horse.destroy
      render json: { message: "Horse deleted for everyone" }, status: :ok
    else
      user_horse.destroy
      render json: { message: "Horse removed from your list" }, status: :ok
    end
  end

  # DELETE /horses/:id/delete_shares
  def delete_shares
    user_horse = UserHorse.find_by(horse_id: @horse.id, user_id: current_user.id)
    unless user_horse&.shared_by == current_user.id || @horse.user_id == current_user.id
      return render json: { error: "Not authorized" }, status: :unauthorized
    end

    UserHorse.where(horse_id: @horse.id, shared_by: current_user.id)
             .where.not(user_id: current_user.id)
             .destroy_all

    render json: { message: "Subsequent shares removed successfully" }, status: :ok
  end

  # GET /horses/:id/pending_approvals
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

  # GET /horses/:id/shares
  def shares
    shared_users = User.joins(:user_horses)
                       .where(user_horses: { horse_id: @horse.id, shared_by: current_user.id })
                       .where.not(id: current_user.id)
                       .select("users.id, users.first_name, users.last_name")

    render json: {
      shares: shared_users.map { |u|
        {
          user_id: u.id,
          user_name: "#{u.first_name} #{u.last_name}"
        }
      }
    }, status: :ok
  end

  # GET /received
  def received_horses
    received = Horse.joins(:user_horses)
                    .where(user_horses: { user_id: current_user.id })
                    .where.not(horses: { user_id: current_user.id })
                    .distinct

    render json: received.map { |horse|
      user_horse = UserHorse.where(horse_id: horse.id, user_id: current_user.id)
                            .order(created_at: :desc)
                            .first

      sender_user = user_horse ? User.find_by(id: user_horse.shared_by) : nil
      sender_name = sender_user ? "#{sender_user.first_name} #{sender_user.last_name}".strip : 'Unknown'

      {
        id: horse.id,
        name: horse.name,
        images: horse.images.map { |image| url_for(image) },
        sender_name: sender_name,
        status: user_horse&.status || 'active'
      }
    }, status: :ok
  end

  # GET /horses/shared/:token
  def shared
    shared_link = SharedLink.find_by(token: params[:token])

    unless shared_link
      return render json: { error: "⚠️ Invalid or expired link.", redirect: '/welcome' }, status: :not_found
    end

    if shared_link.status == 'used'
      return render json: { error: "⚠️ This link has already been used or expired.", redirect: '/welcome' }, status: :forbidden
    end

    unless current_user
      Rails.logger.error "❌ No authenticated user found! Redirecting to login."
      return render json: { error: '⚠️ You need to log in to claim this horse.', redirect: '/welcome' }, status: :unauthorized
    end

    horse = Horse.find_by(id: shared_link.horse_id)
    unless horse
      return render json: { error: "⚠️ Horse not found.", redirect: '/welcome' }, status: :not_found
    end

    if UserHorse.exists?(horse_id: horse.id, user_id: current_user.id)
      return render json: { error: "⚠️ You already have this horse in your collection.", redirect: '/received' }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      UserHorse.create!(
        horse_id: horse.id,
        user_id: current_user.id,
        shared_by: shared_link.shared_by
      )

      sender_user = User.find_by(id: shared_link.shared_by)
      sender_name = sender_user ? "#{sender_user.first_name} #{sender_user.last_name}" : "Unknown"
      recipient_name = "#{current_user.first_name} #{current_user.last_name}"

      log_to_update = Log.where(action: 'shared_via_link', horse_name: horse.name, user_id: shared_link.shared_by)
                         .where("recipient LIKE ?", "Pending%")
                         .order(created_at: :desc)
                         .limit(1)
                         .lock("FOR UPDATE SKIP LOCKED")
                         .first

      if log_to_update
        log_to_update.update!(recipient: recipient_name)
      end

      create_log(action: 'received', horse_name: horse.name, recipient: sender_name, user_id: current_user.id)

      shared_link.update!(status: 'used', used_at: Time.current)

      current_user.increment!(:used_shares)
    end

    render json: { message: "Horse added to your collection!", redirect: '/received' }, status: :ok
  end

  # POST /horses/:id/share_via_link
  def share_via_link
    recent_link = SharedLink.where(horse_id: @horse.id, shared_by: current_user.id)
                            .where("created_at >= ?", 2.seconds.ago)
                            .order(created_at: :desc)
                            .limit(1)
                            .lock("FOR UPDATE SKIP LOCKED")

    if recent_link.exists?
      return render json: { link: "https://www.horsehub.info/horses/shared/#{recent_link.first.token}" }, status: :ok
    end

    if current_user.used_shares.to_i >= current_user.max_shares.to_i
      return render json: { error: "You have reached your sharing limit." }, status: :forbidden
    end

    shared_link = SharedLink.create!(
      horse_id: @horse.id,
      shared_by: current_user.id,
      token: SecureRandom.hex(16),
      status: 'active'
    )

    current_user.increment!(:used_shares)

    create_log(
      action: 'shared_via_link',
      horse_name: @horse.name,
      recipient: "Pending #{SecureRandom.hex(4)}"
    )

    render json: { link: "https://www.horsehub.info/horses/shared/#{shared_link.token}" }, status: :created
  end

  # POST /horses/:id/share_via_email
  def share_via_email
    email = params[:email]

    unless email.present? && email.match?(/\A[^@\s]+@[^@\s]+\z/)
      return render json: { error: "Invalid email." }, status: :unprocessable_entity
    end

    recipient = User.find_by(email: email)

    unless recipient
      return render json: { error: "No user found with this email." }, status: :not_found
    end

    horse = Horse.find_by(id: params[:id])
    unless horse
      return render json: { error: "Horse not found." }, status: :not_found
    end

    if UserHorse.exists?(horse_id: horse.id, user_id: recipient.id)
      return render json: { error: "This user already has this horse." }, status: :unprocessable_entity
    end

    if current_user.used_shares.to_i >= current_user.max_shares.to_i
      return render json: { error: "You have reached your sharing limit." }, status: :forbidden
    end

    UserHorse.create!(horse_id: horse.id, user_id: recipient.id, shared_by: current_user.id)
    current_user.increment!(:used_shares)

    recipient_name = "#{recipient.first_name} #{recipient.last_name}"
    create_log(action: 'shared_via_email', horse_name: horse.name, recipient: recipient_name)

    render json: { message: "Horse successfully shared with #{recipient_name}." }, status: :ok
  end

  private

  def set_horse
  @horse = Horse.left_joins(:user_horses)
                .where(
                  'horses.user_id = :user_id OR user_horses.user_id = :user_id',
                  user_id: current_user.id
                )
                .find_by(id: params[:id])
  render json: { error: "Horse not found" }, status: :not_found unless @horse
end

  def horse_params
    params.require(:horse).permit(
      :name, :age, :gender, :color, :height_cm, :piroplasmosis,
      :breed, :breeder, :training_level, :description,
      images: [], videos: [],
      ancestors: [:name, :breed, :breeder]
    )
  end
end
