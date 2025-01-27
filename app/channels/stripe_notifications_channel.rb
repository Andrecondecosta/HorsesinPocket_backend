class StripeNotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stripe_notifications_#{current_user.id}"  # Subscrição do usuário autenticado
  end

  def unsubscribed
    # Limpeza quando o usuário se desinscreve
  end
end
