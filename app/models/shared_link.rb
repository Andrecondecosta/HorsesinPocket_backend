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

  # Valida se o link está ativo e ainda não foi usado
  def valid_for_one_time_use?
    !expired? && used_at.nil? && status == 'active'
  end

  # Marca o link como usado
  def mark_as_used!
    update!(used_at: Time.current, status: 'used')
  end
end
