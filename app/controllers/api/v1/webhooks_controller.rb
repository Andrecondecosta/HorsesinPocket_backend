class Api::V1::WebhooksController < ActionController::API
  require 'stripe'

  # Endpoint para troca de planos pelo frontend
  def change_plan
    new_plan = params[:plan]

    if new_plan == 'premium'
      if current_user.stripe_customer_id.blank?
        Rails.logger.error("Usuário #{current_user.email} não possui um stripe_customer_id configurado.")
        render json: { error: "ID do cliente no Stripe não configurado." }, status: :unprocessable_entity
        return
      end

      Rails.logger.info("Iniciando criação de subscrição no Stripe para o usuário #{current_user.email}")

      subscription = Stripe::Subscription.create(
        customer: current_user.stripe_customer_id,
        items: [{ price: 'price_1QlcqaDCGWh9lQnCdqRglpSD' }], # Substitua pelo ID do preço correto
        expand: ['latest_invoice.payment_intent']
      )

      Rails.logger.info("Subscrição criada no Stripe: #{subscription.id}")

      current_user.update!(
        plan: 'premium',
        stripe_subscription_id: subscription.id,
        subscription_end: Time.at(subscription.current_period_end),
        used_horses: 0,
        used_shares: 0
      )

      render json: { message: "Subscrição para plano Premium ativada." }, status: :ok

    elsif new_plan == 'free'
      if current_user.stripe_subscription_id.present?
        Rails.logger.info("Cancelando subscrição no Stripe para o usuário #{current_user.email}")

        Stripe::Subscription.delete(current_user.stripe_subscription_id)
      end

      current_user.update!(
        plan: 'free',
        stripe_subscription_id: nil,
        subscription_end: nil,
        used_horses: [current_user.used_horses, 2].min,
        used_shares: [current_user.used_shares, 2].min
      )

      render json: { message: "Plano alterado para Gratuito." }, status: :ok

    else
      render json: { error: "Plano inválido." }, status: :unprocessable_entity
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("Erro no Stripe: #{e.message}")
    render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
  end



  def stripe_webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      # Valida o webhook usando o endpoint_secret do Stripe
      event = Stripe::Webhook.construct_event(payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET'])
    rescue JSON::ParserError => e
      Rails.logger.error("Erro ao processar payload do Stripe: #{e.message}")
      render json: { error: "Payload inválido" }, status: :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Erro de assinatura do Stripe: #{e.message}")
      render json: { error: "Assinatura inválida" }, status: :bad_request
      return
    end

    # Processa o evento com base no tipo
    case event['type']
    when 'customer.subscription.created'
      handle_subscription_created(event)
    when 'customer.subscription.updated'
      handle_subscription_updated(event)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event)
    when 'invoice.payment_succeeded'
      handle_payment_succeeded(event)
    when 'invoice.payment_failed'
      handle_payment_failed(event)
    else
      Rails.logger.info("Evento do Stripe ignorado: #{event['type']}")
    end

    render json: { message: "Webhook processado com sucesso" }, status: :ok
  end

  private

  # --- HANDLERS PARA WEBHOOKS ---

  # Associa o cliente criado no Stripe ao usuário no sistema
  def handle_customer_created(event)
    customer = event['data']['object']
    user = User.find_by(email: customer['email']) # Associa com base no e-mail

    if user
      user.update!(stripe_customer_id: customer['id'])
      Rails.logger.info("Cliente do Stripe associado ao utilizador #{user.email}")
    else
      Rails.logger.error("Utilizador não encontrado para o cliente #{customer['id']}")
    end
  end

  # Lida com criação de subscrição
  def handle_subscription_created(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_customer_id: subscription['customer'])

    if user
      user.update!(
        stripe_subscription_id: subscription['id'],
        plan: 'premium',
        subscription_end: Time.at(subscription['current_period_end']),
        used_horses: 0, # Reset contadores
        used_shares: 0
      )
      Rails.logger.info("Subscrição criada para o utilizador #{user.email}")
    else
      Rails.logger.error("Utilizador não encontrado para o cliente #{subscription['customer']}")
    end
  end

  # Lida com atualização de subscrição
  def handle_subscription_updated(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_subscription_id: subscription['id'])

    if user
      user.update!(
        plan: 'premium',
        subscription_end: Time.at(subscription['current_period_end'])
      )
      Rails.logger.info("Subscrição atualizada para o utilizador #{user.email}")
    else
      Rails.logger.error("Utilizador não encontrado para a subscrição #{subscription['id']}")
    end
  end

  # Lida com cancelamento de subscrição
  def handle_subscription_deleted(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_subscription_id: subscription['id'])

    if user
      user.update!(
        plan: 'free',
        subscription_end: nil,
        used_horses: [user.used_horses, 2].min, # Respeita os limites do plano
        used_shares: [user.used_shares, 2].min
      )
      Rails.logger.info("Subscrição cancelada para o utilizador #{user.email}")
    else
      Rails.logger.error("Utilizador não encontrado para a subscrição #{subscription['id']}")
    end
  end

  # Lida com pagamentos bem-sucedidos
  def handle_payment_succeeded(event)
    invoice = event['data']['object']
    user = User.find_by(stripe_customer_id: invoice['customer'])

    if user
      user.update!(subscription_end: Time.current + 1.month)
      Rails.logger.info("Pagamento bem-sucedido para o utilizador #{user.email}")
    else
      Rails.logger.error("Utilizador não encontrado para o cliente #{invoice['customer']}")
    end
  end

  # Lida com falhas de pagamento
  def handle_payment_failed(event)
    invoice = event['data']['object']
    user = User.find_by(stripe_customer_id: invoice['customer'])

    if user
      Rails.logger.warn("Pagamento falhou para o utilizador #{user.email}")
      user.update!(plan: 'free', subscription_end: nil)
    else
      Rails.logger.error("Utilizador não encontrado para o cliente #{invoice['customer']}")
    end
  end
end
