class UserMailer < ApplicationMailer
  default from: 'no-reply@horsesinpocket.com'

  # E-mail para compartilhar cavalo com usuário existente
  def share_horse_email(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @horse_url = "http://localhost:3000/horses/#{horse.id}"
    mail(to: recipient_email, subject: "#{@sender.name} compartilhou um cavalo com você!")
  end

  # E-mail de convite para novo usuário
  def invite_new_user(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @register_url = "http://localhost:3000/signup"
    mail(to: recipient_email, subject: "#{@sender.name} convida você para conhecer #{horse.name}")
  end
end
