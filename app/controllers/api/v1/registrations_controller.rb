class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  before_action :authorized, except: [:create]

  def show
    render json: current_user.as_json(
      only: [:id, :email, :first_name, :last_name, :birthdate, :phone_number,
             :country, :gender, :admin, :plan, :used_horses, :used_transfers,
             :used_shares, :max_horses, :max_shares, :subscription_end,
             :subscription_canceled, :created_at, :updated_at]
    ), status: :ok
  end

  def create
    user = User.new(user_params)

    unless user.valid?
      return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end

    begin
      customer = Stripe::Customer.create(email: user.email)

      subscription = Stripe::Subscription.create(
        customer: customer.id,
        items: [{ price: "price_1Qo68DDCGWh9lQnCaWeRF1YO" }],
        trial_period_days: 365,
        expand: ["latest_invoice.payment_intent"]
      )

      user.stripe_customer_id     = customer.id
      user.plan                   = "Ultimate"
      user.stripe_subscription_id = subscription.id
      user.subscription_end       = Time.at(subscription.current_period_end)

      user.save!

      if params[:shared_token].present?
        process_shared_horse(user, params[:shared_token])
      end

      token = encode_token({ user_id: user.id })

      render json: { token: token, message: "Usuário criado com sucesso!" }, status: :created

    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      render json: { error: "Registration failed due to a payment service error. Please try again." }, status: :service_unavailable

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "DB error: #{e.message}"
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if current_user.update(user_params)
      render json: current_user, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def process_shared_horse(user, token)
    shared_link = SharedLink.find_by(token: token, status: 'active')
    return unless shared_link

    ActiveRecord::Base.transaction do
      user_horse = UserHorse.create!(
        horse_id: shared_link.horse_id,
        user_id: user.id,
        shared_by: shared_link.shared_by
      )

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
