class Api::V1::WebhooksController < ActionController::API
  before_action :set_stripe_api_key
  require 'stripe'

  # 🔥 Definição dos planos disponíveis e seus respectivos `price_id` no Stripe
  PLAN_PRICES = {
    "Basic" => nil, # Plano gratuito (não precisa de `price_id` no Stripe)
    "Plus" => "price_1Qo67GDCGWh9lQnCP4woIdoo",
    "Premium" => "price_1Qo67nDCGWh9lQnCV35pyiym",
    "Ultimate" => "price_1Qo68DDCGWh9lQnCaWeRF1YO"
  }.freeze

  # Endpoint para troca de planos pelo frontend
  def change_plan
    new_plan = params[:plan]
    price_id = PLAN_PRICES[new_plan] # Obtém o `price_id` correspondente
    Rails.logger.info("Tentando mudar para o plano: #{new_plan}")

    unless PLAN_PRICES.key?(new_plan)
      Rails.logger.error("Plano inválido solicitado: #{new_plan}")
      return render json: { error: "Plano inválido. Escolha entre: #{PLAN_PRICES.keys.join(', ')}" }, status: :unprocessable_entity
    end

    if new_plan == "Basic"
      Rails.logger.info("Resetando contadores para o plano gratuito...")
      begin
        Stripe::Subscription.delete(current_user.stripe_subscription_id) if current_user.stripe_subscription_id
        Rails.logger.info("Subscrição no Stripe cancelada com sucesso.")

        current_user.update!(
          plan: "Basic",
          stripe_subscription_id: nil,
          subscription_end: nil,
          subscription_canceled: false, # 🔥 Resetando após a expiração real
          used_horses: [current_user.used_horses, 2].min,
          used_shares: [current_user.used_shares, 2].min
        )
        render json: { message: "Plano alterado para Gratuito." }, status: :ok
      rescue Stripe::StripeError => e
        Rails.logger.error("Erro ao cancelar subscrição no Stripe: #{e.message}")
        render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
      end

    else
      Rails.logger.info("Criando subscrição no Stripe para #{new_plan}...")
      begin
        subscription = Stripe::Subscription.create(
          customer: current_user.stripe_customer_id,
          items: [{ price: price_id }],
          expand: ['latest_invoice.payment_intent']
        )
        Rails.logger.info("Subscrição criada com sucesso no Stripe. ID: #{subscription.id}")

        current_user.update!(
          plan: new_plan,
          stripe_subscription_id: subscription.id,
          subscription_end: Time.at(subscription.current_period_end),
          subscription_canceled: false, # 🔥 Resetando após a expiração real
          used_horses: 0,
          used_shares: 0
        )
        render json: { message: "Subscrição para plano #{new_plan} ativada." }, status: :ok
      rescue Stripe::StripeError => e
        Rails.logger.error("Erro ao criar subscrição no Stripe: #{e.message}")
        render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
      end
    end
  end

  def stripe_webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET'])
    rescue JSON::ParserError => e
      Rails.logger.error("Erro ao processar payload do Stripe: #{e.message}")
      return render json: { error: "Payload inválido" }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Erro de assinatura do Stripe: #{e.message}")
      return render json: { error: "Assinatura inválida" }, status: :bad_request
    end

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

  def handle_subscription_created(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_customer_id: subscription['customer'])
    plan_name = get_plan_name_from_price(subscription['items']['data'][0]['price']['id'])

    Rails.logger.info("🔥 RECEBIDO: Subscription Created - Cliente #{subscription['customer']}")

    if user
      Rails.logger.info("🔄 Atualizando usuário #{user.email} para plano #{plan_name}")

      user.update!(
        stripe_subscription_id: subscription['id'],
        plan: plan_name,
        subscription_end: Time.at(subscription['current_period_end']),
        subscription_canceled: false, # ✅ Resetando
        used_horses: 0,
        used_shares: 0
      )
      user.reload # 🔥 Garante que os dados foram salvos
      Rails.logger.info("✅ Atualizado! subscription_canceled: #{user.subscription_canceled}")
    else
      Rails.logger.error("❌ Usuário não encontrado para cliente #{subscription['customer']}")
    end
  end

  def handle_subscription_updated(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_subscription_id: subscription['id'])

    Rails.logger.info("🔥 RECEBIDO: Subscription Updated - Sub ID #{subscription['id']}")

    if user
      new_plan = get_plan_name_from_price(subscription['items']['data'][0]['price']['id'])
      Rails.logger.info("🔄 Atualizando #{user.email} para #{new_plan}")

      begin
        user.update!(
          plan: new_plan,
          subscription_end: Time.at(subscription['current_period_end']),
          subscription_canceled: false # ✅ Resetando
        )

        user.reload # 🔥 Confirmação após update
        Rails.logger.info("✅ Atualizado! subscription_canceled: #{user.subscription_canceled}")
      rescue => e
        Rails.logger.error("❌ ERRO AO ATUALIZAR USER: #{e.message}")
      end
    else
      Rails.logger.error("❌ Usuário não encontrado para a assinatura #{subscription['id']}")
    end
  end





  def handle_subscription_deleted(event)
    subscription = event['data']['object']
    user = User.find_by(stripe_subscription_id: subscription['id'])

    if user
      user.update!(
        subscription_canceled: true # 🔥 Mantém como true até a expiração
      )
      Rails.logger.info("❌ Assinatura cancelada para #{user.email}. subscription_canceled: true")
    else
      Rails.logger.error("⚠️ Usuário não encontrado para a assinatura #{subscription['id']}")
    end
  end


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

  def handle_payment_failed(event)
    invoice = event['data']['object']
    user = User.find_by(stripe_customer_id: invoice['customer'])

    if user
      Rails.logger.warn("⚠️ Pagamento falhou para #{user.email}. Voltando para o plano Basic.")

      user.update!(
        plan: "Basic",
        subscription_end: nil,
        stripe_subscription_id: nil
      )
    else
      Rails.logger.error("Usuário não encontrado para o cliente #{invoice['customer']}")
    end
  end


  def get_plan_name_from_price(price_id)
    PLAN_PRICES.key(price_id) || "Basic" # Retorna "Basic" como padrão se não encontrar o preço
  end

  def set_stripe_api_key
    Stripe.api_key = ENV['STRIPE_API_KEY']
  end
end
