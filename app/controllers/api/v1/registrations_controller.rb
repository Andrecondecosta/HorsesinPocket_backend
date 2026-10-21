class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  before_action :authorized, except: [:create]

  PROFILE_FIELDS = %i[id email first_name last_name birthdate phone_number
                      country gender admin plan used_horses used_transfers
                      used_shares max_horses max_shares subscription_end
                      subscription_canceled created_at updated_at].freeze

  def show
    render json: current_user.as_json(only: PROFILE_FIELDS), status: :ok
  end

  def create
    user = User.new(user_params)

    unless user.valid?
      return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end

    # O HorseHub é gratuito: a conta nova fica no plano sem limites ("Ultimate"),
    # sem cliente nem subscrição no Stripe. Sem subscription_end, nunca é despromovida.
    user.plan = "Ultimate"

    begin
      user.save!

      if params[:shared_token].present?
        process_shared_horse(user, params[:shared_token])
      end

      token = encode_token({ user_id: user.id })

      render json: { token: token, message: "Usuário criado com sucesso!" }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "DB error: #{e.message}"
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if current_user.update(user_params)
      # Mesmos campos do GET /profile; o User inteiro chamava o Stripe (stripe_default_payment_method)
      render json: current_user.as_json(only: PROFILE_FIELDS), status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def process_shared_horse(user, token)
    shared_link = SharedLink.find_by(token: token, status: 'active')
    return unless shared_link

    ActiveRecord::Base.transaction do
      user_horse = UserHorse.new(
        horse_id: shared_link.horse_id,
        user_id: user.id,
        # Como no login: se o link não guardou quem partilhou, fica o dono do cavalo
        shared_by: shared_link.shared_by || shared_link.horse.user_id
      )
      shared_link.grant_permissions_to(user_horse)
      user_horse.save!

      sender_user = User.find_by(id: shared_link.shared_by)
      sender_name = sender_user ? "#{sender_user.first_name} #{sender_user.last_name}" : "Unknown"
      recipient_name = "#{user.first_name} #{user.last_name}"

      log_to_update = Log.where(action: 'shared_via_link', horse_name: user_horse.horse.name, user_id: shared_link.shared_by)
                         .where("recipient LIKE ?", "Pending%")
                         .order(created_at: :desc)
                         .limit(1)
                         .lock("FOR UPDATE SKIP LOCKED")
                         .first

      log_to_update&.update!(recipient: recipient_name)

      create_log(action: 'received', horse_name: user_horse.horse.name, recipient: sender_name, user_id: user.id)

      shared_link.update!(status: 'used', used_at: Time.current)
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :password,
      :password_confirmation, :birthdate, :phone_number, :gender, :country
    )
  end
end
