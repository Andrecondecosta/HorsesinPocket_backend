class Api::V1::UsersController < ApplicationController
  before_action :authorized # Para garantir que o usuário está autenticado

  def change_plan
    new_plan = params[:plan]
    Rails.logger.info "Tentando mudar para o plano: #{new_plan}"

    ActiveRecord::Base.transaction do
      if new_plan == "free"
        # Ajusta os contadores primeiro
        current_user.update!(used_horses: 0, used_shares: 0)
        Rails.logger.info "Resetando contadores para o plano gratuito"
      end

      # Atualiza o plano depois
      current_user.update!(plan: new_plan)
    end

    render json: { message: "Plano alterado com sucesso.", plan: new_plan }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Erro ao mudar plano: #{e.record.errors.full_messages.join(', ')}"
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end





  def get_user_plan
    user = current_user  # Obtém o usuário autenticado

    if user
      # Retorna o plano do usuário
      render json: { plan: user.plan }, status: :ok
    else
      # Caso não encontre o usuário
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  private

  def update_stripe_subscription(stripe_customer_id, stripe_subscription_id, new_plan)
    # IDs dos planos do Stripe
    plan_id = new_plan == 'premium' ? 'price_1QkqTDCGWh9lQnCUW8zCkX6' : 'price_1QkqTDCGWh9lQnC3j4hT5w9'  # Plano gratuito com valor 0

    # Obtém a assinatura do Stripe para verificar os itens
    stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)

    # Se a assinatura tiver itens, atualiza o preço do item correto
    if stripe_subscription.items.data.any?
      item_id = stripe_subscription.items.data[0].id

      # Atualiza a assinatura do Stripe com o novo plano
      Stripe::Subscription.update(
        stripe_subscription_id,
        {
          items: [{
            id: item_id,
            price: plan_id  # Novo plano (premium ou gratuito)
          }]
        }
      )
    else
      # Se não encontrar nenhum item, lança erro
      raise StandardError, "Nenhum item encontrado na assinatura do Stripe"
    end
  end
end
