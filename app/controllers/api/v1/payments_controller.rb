class Api::V1::PaymentsController < ApplicationController
  before_action :authorized # Garante que o usuário está autenticado

  def create_setup_intent
    user = current_user

    if user.stripe_customer_id.blank?
      customer = Stripe::Customer.create(email: user.email)
      user.update!(stripe_customer_id: customer.id)
    end

    setup_intent = Stripe::SetupIntent.create(customer: user.stripe_customer_id)

    render json: { client_secret: setup_intent.client_secret }, status: :ok
  rescue Stripe::StripeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end


  def create_payment_intent
    user = current_user
    price_id = params[:price_id]
    payment_method_id = params[:payment_method_id]

    Rails.logger.info "🔍 Criando Payment Intent para #{user.email} no plano #{params[:plan]} (#{price_id})"

    # 🚀 1️⃣ Anexar o método de pagamento ao cliente, se ainda não estiver anexado
    begin
      Stripe::PaymentMethod.attach(payment_method_id, { customer: user.stripe_customer_id })
      Rails.logger.info "✅ Método de pagamento anexado ao cliente #{user.stripe_customer_id}"
    rescue Stripe::InvalidRequestError => e
      Rails.logger.warn("⚠️ Método já anexado ou erro ignorável: #{e.message}")
    rescue Stripe::StripeError => e
      Rails.logger.error("❌ Erro ao anexar método de pagamento: #{e.message}")
      return render json: { error: "Erro ao anexar método de pagamento: #{e.message}" }, status: :unprocessable_entity
    end

    # 🚀 2️⃣ Definir como método de pagamento padrão do cliente
    begin
      Stripe::Customer.update(user.stripe_customer_id, invoice_settings: { default_payment_method: payment_method_id })
      Rails.logger.info "✅ Método de pagamento definido como padrão"
    rescue Stripe::StripeError => e
      Rails.logger.error("❌ Erro ao definir método de pagamento padrão: #{e.message}")
      return render json: { error: "Erro ao definir método de pagamento padrão: #{e.message}" }, status: :unprocessable_entity
    end

    # 🚀 3️⃣ Criar assinatura no Stripe com o price_id correto
    begin
      subscription = Stripe::Subscription.create(
        customer: user.stripe_customer_id,
        items: [{ price: price_id }],
        default_payment_method: payment_method_id, # ✅ Usa o método de pagamento salvo
        expand: ["latest_invoice.payment_intent"]
      )
      Rails.logger.info "✅ Assinatura criada no Stripe: #{subscription.id}"

      # ✅ Atualiza o usuário no banco de dados
      user.update!(
        stripe_subscription_id: subscription.id,
        plan: get_plan_name_from_price(price_id),
        subscription_canceled: false,
        subscription_end: Time.at(subscription.current_period_end)
      )

      render json: { message: "Plano atualizado para #{user.plan}!" }, status: :ok
    rescue Stripe::StripeError => e
      Rails.logger.error("❌ Erro ao criar assinatura no Stripe: #{e.message}")
      render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def cancel_subscription
    user = current_user

    begin
      subscription = Stripe::Subscription.update(
        user.stripe_subscription_id,
        { cancel_at_period_end: true } # ✅ Mantém a assinatura ativa até o fim do período
      )

      # ✅ Agora marcamos que a assinatura foi cancelada
      user.update!(
        subscription_canceled: true,
        subscription_end: Time.at(subscription.current_period_end) # Mantém a data de expiração
      )

      render json: {
        message: "Sua assinatura foi cancelada e permanecerá ativa até #{user.subscription_end.strftime('%d/%m/%Y')}.",
        subscription_end: user.subscription_end,
        subscription_canceled: true
      }, status: :ok
    rescue Stripe::StripeError => e
      render json: { error: "Erro ao cancelar assinatura: #{e.message}" }, status: :unprocessable_entity
    end
  end





  private

  def get_plan_name_from_price(price_id)
    {
      "price_1Qo67GDCGWh9lQnCP4woIdoo" => "Plus",
      "price_1Qo67nDCGWh9lQnCV35pyiym" => "Premium",
      "price_1Qo68DDCGWh9lQnCaWeRF1YO" => "Ultimate"
    }[price_id] || "Basic"  # 🔥 Retorna "Basic" se o price_id não for encontrado
  end

  end
