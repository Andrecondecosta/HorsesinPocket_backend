class Api::V1::UsersController < ApplicationController
  before_action :authorized # Garante que o usuário está autenticado

  # 🔥 Definição dos planos disponíveis e seus respectivos `price_id` do Stripe
  PLAN_PRICES = {
    "Basic" => nil, # Plano gratuito (não tem price_id no Stripe)
    "Plus" => "price_1Qo67GDCGWh9lQnCP4woIdoo",
    "Premium" => "price_1Qo67nDCGWh9lQnCV35pyiym",
    "Ultimate" => "price_1Qo68DDCGWh9lQnCaWeRF1YO"
  }.freeze

  def change_plan
    new_plan = params[:plan]
    price_id = PLAN_PRICES[new_plan] # Obtém o `price_id` correspondente ao plano escolhido
    Rails.logger.info "Tentando mudar para o plano: #{new_plan}"

    # 🚨 Valida se o plano é válido antes de continuar
    unless PLAN_PRICES.key?(new_plan)
      Rails.logger.error "Plano inválido solicitado: #{new_plan}"
      return render json: { error: "Plano inválido. Escolha entre: #{PLAN_PRICES.keys.join(', ')}" }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      user = current_user

      # Criar cliente no Stripe se ainda não existir
      if user.stripe_customer_id.blank?
        customer = Stripe::Customer.create(email: user.email)
        user.update!(stripe_customer_id: customer.id)
        Rails.logger.info "Cliente criado no Stripe: #{customer.id}"
      end

      if new_plan == "Basic"
        # Cancela qualquer assinatura existente no Stripe
        if user.stripe_subscription_id.present?
          Stripe::Subscription.update(user.stripe_subscription_id, cancel_at_period_end: true)
          user.update!(stripe_subscription_id: nil)
          Rails.logger.info "Assinatura cancelada no Stripe"
        end

        # Reseta contadores e atualiza para o plano gratuito
        user.update!(
          used_horses: 0,
          used_shares: 0,
          plan: "Basic"
        )
        Rails.logger.info "Plano alterado para gratuito com sucesso"

      else
        # Adiciona um método de pagamento padrão ao cliente (se necessário)
        unless Stripe::Customer.retrieve(user.stripe_customer_id).invoice_settings.default_payment_method
          Rails.logger.info "Adicionando método de pagamento ao cliente no Stripe"
          payment_method = Stripe::PaymentMethod.list(
            customer: user.stripe_customer_id,
            type: 'card'
          ).data.first

          if payment_method.present?
            Stripe::Customer.update(
              user.stripe_customer_id,
              invoice_settings: { default_payment_method: payment_method.id }
            )
            Rails.logger.info "Método de pagamento #{payment_method.id} associado ao cliente #{user.stripe_customer_id}"
          else
            raise "Nenhum método de pagamento encontrado para o cliente #{user.stripe_customer_id}. Por favor, adicione um cartão."
          end
        end

        if user.stripe_subscription_id.present?
          # Atualiza a assinatura existente
          subscription = Stripe::Subscription.retrieve(user.stripe_subscription_id)
          Stripe::Subscription.update(
            user.stripe_subscription_id,
            {
              items: [{
                id: subscription.items.data[0].id,
                price: price_id
              }]
            }
          )
          Rails.logger.info "Assinatura do Stripe atualizada para #{new_plan}"
        else
          # Criar uma nova assinatura no Stripe
          subscription = Stripe::Subscription.create(
            customer: user.stripe_customer_id,
            items: [{ price: price_id }]
          )
          user.update!(stripe_subscription_id: subscription.id)
          Rails.logger.info "Nova assinatura criada no Stripe: #{subscription.id}"
        end

        # Atualiza o plano no banco de dados
        user.update!(plan: new_plan)
        Rails.logger.info "Plano atualizado para #{new_plan} com sucesso"
      end
    end

    render json: { message: "Plano alterado com sucesso para #{new_plan}" }, status: :ok
  rescue Stripe::StripeError => e
    Rails.logger.error "Erro no Stripe: #{e.message}"
    render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Erro na mudança de plano: #{e.message}"
    render json: { error: "Erro ao mudar de plano: #{e.message}" }, status: :unprocessable_entity
  end

  def get_user_plan
    user = current_user  # Obtém o usuário autenticado

    if user
      render json: { plan: user.plan }, status: :ok
    else
      render json: { error: 'Usuário não encontrado' }, status: :not_found
    end
  end

  def get_user_status
    user = current_user

    render json: {
      plan: current_user.plan,
      used_horses: current_user.used_horses,
      max_horses: current_user.max_horses || 0,  # 🔥 Garante que não seja nil
      used_shares: current_user.used_shares,
      max_shares: current_user.max_shares || 0   # 🔥 Garante que não seja nil
    }
  end


  private

  def reset_counters_for_free_plan
    current_user.update!(used_horses: 0, used_shares: 0)
  end

  def update_stripe_subscription(stripe_customer_id, stripe_subscription_id, new_plan)
    Rails.logger.info "Iniciando atualização da assinatura no Stripe para o cliente #{stripe_customer_id} com o plano #{new_plan}"

    # Obtém o `price_id` correspondente ao plano
    plan_id = PLAN_PRICES[new_plan]

    # Obtém a assinatura do Stripe
    stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)

    if stripe_subscription.items.data.any?
      item_id = stripe_subscription.items.data[0].id
      Stripe::Subscription.update(
        stripe_subscription_id,
        {
          items: [{
            id: item_id,
            price: plan_id # Atualiza para o novo plano
          }]
        }
      )
      Rails.logger.info "Assinatura atualizada com sucesso no Stripe para o plano #{new_plan}"
    else
      raise StandardError, "Nenhum item encontrado na assinatura do Stripe"
    end
  end
end
