class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  before_action :authorized, except: [:create]

  def show
    render json: current_user, status: :ok
  end

  def create
    user = User.new(user_params)

    # Validate before any external calls — fail fast with clear errors
    unless user.valid?
      return render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end

    begin
      # Call Stripe BEFORE persisting the user.
      # If Stripe is unavailable, nothing is written to the DB
      # and the user can safely retry with the same email.
      customer = Stripe::Customer.create(email: user.email)

      subscription = Stripe::Subscription.create(
        customer: customer.id,
        items: [{ price: "price_1Qo68DDCGWh9lQnCaWeRF1YO" }],
        trial_period_days: 365,
        expand: ["latest_invoice.payment_intent"]
      )

      # Assign all Stripe data to the unsaved user object
      user.stripe_customer_id     = customer.id
      user.plan                   = "Ultimate"
      user.stripe_subscription_id = subscription.id
      user.subscription_end       = Time.at(subscription.current_period_end)

      # Persist the user with all data in a single write
      user.save!

      Rails.logger.info "✅ Novo utilizador registado: #{user.first_name} #{user.last_name}"

      if params[:shared_token].present?
        process_shared_horse(user, params[:shared_token])
      end

      token = encode_token({ user_id: user.id })

      render json: { token: token, message: "Usuário criado com sucesso! Você ganhou 3 meses grátis do Ultimate." }, status: :created

    rescue Stripe::StripeError => e
      Rails.logger.error "❌ Stripe error during registration for #{user.email}: #{e.message}"
      render json: { error: "Registration failed due to a payment service error. Please try again." }, status: :service_unavailable

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ DB error during registration for #{user.email}: #{e.message}"
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
    Rails.logger.info "🔄 Processando cavalo partilhado com token: #{token} para utilizador #{user.id}"

    shared_link = SharedLink.find_by(token: token, status: 'active')

    unless shared_link
      Rails.logger.warn "⚠️ Token de partilha inválido ou já usado: #{token}"
      return
    end

    ActiveRecord::Base.transaction do
      # Associa o cavalo ao novo utilizador
      user_horse = UserHorse.create!(
        horse_id: shared_link.horse_id,
        user_id: user.id,
        shared_by: shared_link.shared_by
      )
      Rails.logger.info "✅ Cavalo #{shared_link.horse_id} associado a #{user.id}"

      # Atualizar o log "shared_via_link" do remetente
      sender_user = User.find_by(id: shared_link.shared_by)
      sender_name = sender_user ? "#{sender_user.first_name} #{sender_user.last_name}" : "Unknown"
      recipient_name = "#{user.first_name} #{user.last_name}"

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

      # Criar um novo log indicando que o cavalo foi recebido
      create_log(action: 'received', horse_name: user_horse.horse.name, recipient: sender_name, user_id: user.id)

      Rails.logger.info "✅ Log de 'received' criado com sucesso para #{recipient_name}"

      # Marcar o link como usado com `used_at`
      shared_link.update!(status: 'used', used_at: Time.current)
      Rails.logger.info "🔒 Token de partilha marcado como usado."
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :birthdate, :phone_number, :gender, :country)
  end
end
