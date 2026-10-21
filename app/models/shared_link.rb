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

  # Passa a permissão de voltar a partilhar para quem recebe pelo link.
  # Só acrescenta: um link sem permissão não tira a que a pessoa já tenha.
  def grant_permissions_to(user_horse)
    user_horse.can_reshare = true if can_reshare
  end

  # Marca o link como usado
  def mark_as_used!
    update!(used_at: Time.current, status: 'used')
  end
end
