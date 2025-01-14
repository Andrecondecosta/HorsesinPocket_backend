class UserMailer < ApplicationMailer
  default from: 'no-reply@horsesinpocket.com'

  # Email to share a horse with an existing user
  def share_horse_email(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @horse_url = "#{ENV['REACT_APP_API_SERVER_URL']}/horses/#{horse.id}"
    mail(to: recipient_email, subject: "#{@sender.name} has shared a horse with you!")
  end

  # Invitation email for a new user
  def invite_new_user(sender, recipient_email, horse)
    @sender = sender
    @horse = horse
    @register_url = "#{ENV['REACT_APP_API_SERVER_URL']}/signup"
    mail(to: recipient_email, subject: "#{@sender.name} invites you to check out #{horse.name}")
  end

  # Confirmation email
  def confirmation_email(user)
    @user = user
    @confirmation_url = confirm_user_url(@user) # Generates the confirmation URL
    mail(to: @user.email, subject: "Email Confirmation - HorseHub")
  end

  # Password reset email
  def password_reset_email(user, token)
    @user = user
    @token = token
    mail(to: @user.email, subject: 'Reset Your Password')
  end
end
