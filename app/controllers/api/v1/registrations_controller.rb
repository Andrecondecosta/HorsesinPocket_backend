class Api::V1::RegistrationsController < ApplicationController
  skip_before_action :authorized, only: [:create]
  before_action :authorized, except: [:create]

  def show
    render json: current_user, status: :ok
  end

  def create
    user = User.new(user_params)

    if user.save
      if params[:shared_token].present?
        shared_link = SharedLink.find_by(token: params[:shared_token])

        if shared_link
          # Associa o cavalo ao usuário
          UserHorse.create!(
            horse_id: shared_link.horse_id,
            user_id: user.id,
            shared_by: shared_link.horse.user_id
          )

          # Marca o link como usado
          shared_link.update!(status: 'used')
        else
          render json: { error: 'Shared token inválido' }, status: :unprocessable_entity
          return
        end
      end

      # ✅ Só cria o cliente Stripe depois de salvar o usuário no banco
      # Criar cliente Stripe para o usuário
      customer = Stripe::Customer.create(email: user.email)
      user.update!(stripe_customer_id: customer.id)

      # Criar assinatura no Ultimate com 3 meses grátis
      subscription = Stripe::Subscription.create(
        customer: user.stripe_customer_id,
        items: [{ price: "price_1Qo68DDCGWh9lQnCaWeRF1YO" }], # ID do plano Ultimate no Stripe
        trial_period_days: 90, # 🔥 3 meses grátis
        expand: ["latest_invoice.payment_intent"]
      )

      # Atualiza o usuário com os detalhes da assinatura
      user.update!(
        plan: "Ultimate",
        stripe_subscription_id: subscription.id,
        subscription_end: Time.at(subscription.current_period_end)
      )


      # Gera token JWT para autenticação
      token = encode_token({ user_id: user.id })


      render json: { token: token, message: "Usuário criado com sucesso! Você ganhou 3 meses grátis do Ultimate." }, status: :created

    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end

  rescue Stripe::StripeError => e
    render json: { error: "Erro no Stripe: #{e.message}" }, status: :unprocessable_entity
  end

  def update
    if current_user.update(user_params)
      render json: current_user, status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :birthdate, :phone_number, :gender, :country)
  end
end
