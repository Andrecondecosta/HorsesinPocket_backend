class SharedLink < ApplicationRecord
  belongs_to :horse

  before_create :generate_token

  # Gera um token único antes de criar o link
  def generate_token
    self.token = SecureRandom.urlsafe_base64(10) unless self.token.present?
  end

  # Verifica se o link está expirado
  def expired?
    expires_at.present? && Time.current > expires_at
  end

  # Valida se o link está ativo
  def active?
    !expired? && status == 'active'
  end
end
