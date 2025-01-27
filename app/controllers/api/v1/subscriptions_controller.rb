class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create_or_renew
    plan = params[:plan] # Ex.: "premium"
    price_id = params[:price_id] # ID do preço do Stripe

    begin
      # Cria o cliente no Stripe, se necessário
      unless current_user.stripe_customer_id
        customer = Stripe::Customer.create({
          email: current_user.email,
          name: current_user.name
        })
        current_user.update!(stripe_customer_id: customer.id)
      end

      # Cria a subscrição no Stripe
      subscription = Stripe::Subscription.create({
        customer: current_user.stripe_customer_id,
        items: [{ price: price_id }]
      })

      # Atualiza os dados no sistema
      if current_user.subscription_end && current_user.subscription_end > Time.current
        # Adiciona 1 mês ao ciclo existente
        current_user.update!(
          subscription_end: current_user.subscription_end + 1.month,
          used_horses: 0,
          used_transfers: 0,
          used_shares: 0,
          plan: plan
        )
      else
        # Inicia um novo ciclo
        current_user.update!(
          subscription_end: Time.current + 1.month,
          used_horses: 0,
          used_transfers: 0,
          used_shares: 0,
          plan: plan
        )
      end

      render json: { message: "Subscrição criada ou renovada com sucesso!", subscription_id: subscription.id }, status: :ok
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
