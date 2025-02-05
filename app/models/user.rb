class User < ApplicationRecord
  has_many :horses, dependent: :destroy
  has_many :user_horses, dependent: :destroy

  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :validatable

  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  scope :active_subscriptions, -> { where("subscription_end > ?", Time.current) }
  scope :expired_subscriptions, -> { where("subscription_end <= ?", Time.current) }

  before_save :set_limits_based_on_plan
  before_save :adjust_usage_counters

  def name
    "#{first_name} #{last_name}"
  end

  def admin?
    self.admin
  end

  PLAN_LIMITS = {
    "Basic" => { horses: 1, shares: 6 },
    "Plus" => { horses: 2, shares: 40 },
    "Premium" => { horses: 6, shares: 60 },
    "Ultimate" => { horses: Float::INFINITY, shares: Float::INFINITY }
  }.freeze

  def set_limits_based_on_plan
    limits = PLAN_LIMITS[self.plan] || PLAN_LIMITS["Basic"]
    self.max_horses = limits[:horses]
    self.max_shares = limits[:shares]
  end

  def adjust_usage_counters
    self.used_horses = [used_horses || 0, max_horses || 0].min
    self.used_shares = [used_shares || 0, max_shares || 0].min
  end


  def cancel_subscription!
    update!(
      plan: "Basic",
      stripe_subscription_id: nil,
      subscription_end: nil
    )
    adjust_usage_counters
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

    trial_days = price_id == "price_1Qo68DDCGWh9lQnCaWeRF1YO" ? 90 : 0  # 🎁 3 meses grátis no Ultimate

    subscription = Stripe::Subscription.create(
      customer: stripe_customer_id,
      items: [{ price: price_id }],
      trial_period_days: trial_days
    )
    update!(stripe_subscription_id: subscription.id, subscription_end: Time.current + 1.month)
  end

  def stripe_default_payment_method
    return nil if stripe_customer_id.blank?

    Stripe::Customer.retrieve(stripe_customer_id).invoice_settings.default_payment_method
  end

  def self.reset_free_plan_limits
    where(plan: "Basic").update_all(used_shares: 0, used_horses: 0)
    Rails.logger.info "✅ Limites de partilhas e cavalos resetados para usuários no plano Basic."
  end

  private

  def validate_horse_limit
    if used_horses > max_horses
      errors.add(:used_horses, "Você atingiu o limite de #{max_horses} cavalos no plano #{plan}.")
    end
  end

  def validate_share_limit
    if used_shares > max_shares
      errors.add(:used_shares, "Você atingiu o limite de #{max_shares} partilhas no plano #{plan}.")
    end
  end
end
