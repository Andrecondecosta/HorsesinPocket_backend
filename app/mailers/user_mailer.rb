class UserMailer < ApplicationMailer
  default from: 'no-reply@horsesinpocket.com'

  # E-mail para compartilhar cavalo com usuário existente
  def share_horse_email(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @horse_url = "#{ENV['REACT_APP_API_SERVER_URL']}/horses/#{horse.id}"
    mail(to: recipient_email, subject: "#{@sender.name} compartilhou um cavalo com você!")
  end

  # E-mail de convite para novo usuário
  def invite_new_user(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @register_url = "#{ENV['REACT_APP_API_SERVER_URL']}/signup"
    mail(to: recipient_email, subject: "#{@sender.name} convida você para conhecer #{horse.name}")
  end

  def confirmation_email(user)
    @user = user
    mail(to: @user.email, subject: 'Confirmação de Cadastro')
  end
end
