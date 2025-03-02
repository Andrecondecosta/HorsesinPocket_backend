class Api::V1::SessionsController < ApplicationController
  skip_before_action :authorized, only: [:create]

  def create
    user = User.find_by(email: params[:email])

    if user && user.valid_password?(params[:password])
      token = encode_token({ user_id: user.id })

      if params[:shared_token].present?
        Rails.logger.info("🔹 Received shared_token: #{params[:shared_token]}")

        shared_link = SharedLink.find_by(token: params[:shared_token])

        if shared_link
          horse = Horse.find_by(id: shared_link.horse_id)

          if horse
            Rails.logger.info("🔄 Associating horse #{horse.id} with user #{user.id}")

            user_horse = UserHorse.find_or_initialize_by(horse_id: horse.id, user_id: user.id)

            if user_horse.persisted?
              Rails.logger.info("✅ User #{user.id} already has horse #{horse.id}. No action necessary.")
            else
              user_horse.shared_by = shared_link.shared_by || horse.user_id
              user_horse.save!
              Rails.logger.info("✅ Horse #{horse.id} successfully added to user #{user.id}.")

              sender_user = User.find_by(id: shared_link.shared_by) # Captura quem enviou

              # 🔹 Criar log de "received" com o nome correto do remetente
              create_log(action: 'received', horse_name: horse.name, recipient: sender_user&.name || 'Unknown', user_id: user.id)

              shared_link.update!(status: 'used', used_at: Time.current)
              Rails.logger.info("🔒 Sharing link marked as 'used'.")
            end
          end
        else
          Rails.logger.info("❌ Invalid sharing token")
        end
      end

      render json: { token: token }, status: :ok
    else
      render json: { error: 'Invalid username or password' }, status: :unauthorized
    end
  end


  def confirm_email
    user = User.find_by(id: params[:id])

    if user && !user.email_confirmed?
      user.update(email_confirmed: true, confirmed_at: Time.current)
      render json: { message: "Email confirmado com sucesso!" }, status: :ok
    else
      render json: { error: "Email já confirmado ou inválido." }, status: :unprocessable_entity
    end
  end
end
