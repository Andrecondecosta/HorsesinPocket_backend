class Api::V1::SubscriptionsController < ApplicationController
  before_action :authorized # Garante que o usuário está autenticado

  def create_or_renew
    plan = params[:plan] # Ex.: "premium"
    price_id = params[:price_id] # ID do preço do Stripe

    begin
      # Cria o cliente no Stripe, se necessário
      unless current_user.stripe_customer_id
        customer = Stripe::Customer.create({
          email: current_user.email,
          name: "#{current_user.first_name} #{current_user.last_name}"
        })
        current_user.update!(stripe_customer_id: customer.id)
      end

      # 🚨 Verifica se há um método de pagamento salvo
      if current_user.stripe_default_payment_method.blank?
        return render json: { error: "Método de pagamento não encontrado." }, status: :unprocessable_entity
      end

      trial_days = price_id == "price_1Qo68DDCGWh9lQnCaWeRF1YO" ? 90 : 0  # Apenas Ultimate ganha 3 meses grátis!
      # Criar subscrição no Stripe
      subscription = Stripe::Subscription.create({
        customer: current_user.stripe_customer_id,
        items: [{ price: price_id }],
        default_payment_method: current_user.stripe_default_payment_method,
        collection_method: "charge_automatically",
        expand: ["latest_invoice.payment_intent"]
      })

      # Atualizar dados do usuário
      current_user.update!(
        subscription_end: (current_user.subscription_end && current_user.subscription_end > Time.current) ?
          current_user.subscription_end + 1.month : Time.current + 1.month,
        used_horses: 0,
        used_transfers: 0,
        used_shares: 0,
        plan: plan,
        stripe_subscription_id: subscription.id
      )

      Rails.logger.info "📝 Subscrição criada: #{subscription.id}"

      render json: {
        message: "Subscrição criada com sucesso!",
        subscription_id: subscription.id,
        status: subscription.status
      }, status: :ok

    rescue Stripe::StripeError => e
      Rails.logger.error "❌ Erro no Stripe: #{e.message}"
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "❌ Erro inesperado: #{e.message}"
      render json: { error: "Erro interno no servidor." }, status: :internal_server_error
    end
  end
end
