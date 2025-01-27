class User < ApplicationRecord
  has_many :horses, dependent: :destroy
  has_many :user_horses, dependent: :destroy

  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :validatable

  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  scope :active_subscriptions, -> { where("subscription_end > ?", Time.current) }
  scope :expired_subscriptions, -> { where("subscription_end <= ?", Time.current) }

  validate :validate_horse_limit, if: -> { plan == "free" }
  validate :validate_share_limit, if: -> { plan == "free" }

  def name
    "#{first_name} #{last_name}"
  end

  def admin?
    self.admin
  end

  def adjust_limits_for_plan_change
    case plan
    when "free"
      Rails.logger.info "Resetando limites para o plano gratuito..."
      update!(
        used_horses: 0,  # Resetar contadores de cavalos
        used_shares: 0   # Resetar contadores de partilhas
      )
    when "premium"
      Rails.logger.info "Plano premium, sem ajustes necessários."
      # No plano premium, os contadores permanecem inalterados
    end
  end

  def horse_limit
    case plan
    when "free"
      2
    when "premium"
      Float::INFINITY
    else
      0
    end
  end

  def share_limit
    case plan
    when "free"
      4
    when "premium"
      Float::INFINITY
    else
      0
    end
  end


  def cancel_subscription!
    update!(
      plan: "free",
      stripe_subscription_id: nil,
      subscription_end: nil,
      used_horses: [used_horses, horse_limit].min,
      used_shares: [used_shares, share_limit].min
    )
  end

  def create_stripe_customer!
    customer = Stripe::Customer.create(
      email: email,
      name: name
    )
    update!(stripe_customer_id: customer.id)
  end

  def create_subscription!(price_id)
    raise "Stripe customer ID not set" if stripe_customer_id.blank?

    subscription = Stripe::Subscription.create(
      customer: stripe_customer_id,
      items: [{ price: price_id }]
    )
    update!(stripe_subscription_id: subscription.id, subscription_end: Time.current + 1.month)
  end

  def self.reset_free_plan_limits
    where(plan: "free").update_all(used_shares: 0)
    Rails.logger.info "Limites de partilhas resetados para usuários no plano gratuito."
  end

  private

  def validate_horse_limit
    if used_horses > horse_limit
      errors.add(:used_horses, "Você atingiu o limite de 2 cavalos no plano gratuito.")
    end
  end

  def validate_share_limit
    if used_shares > share_limit
      errors.add(:used_shares, "Você atingiu o limite de 2 partilhas mensais no plano gratuito.")
    end
  end
end
