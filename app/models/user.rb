class User < ApplicationRecord


  has_many :horses, dependent: :destroy
  has_many :user_horses, dependent: :destroy

  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :validatable

  validates :first_name, :last_name, presence: true
  validates :email, uniqueness: true

  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  scope :active_subscriptions, -> { where("subscription_end > ?", Time.current) }
  scope :expired_subscriptions, -> { where("subscription_end <= ?", Time.current) }

  before_validation :set_limits_based_on_plan
  before_save :adjust_usage_counters
  before_save :downcase_email

  def downcase_email
    self.email = email.downcase if email.present?
  end

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
    "Ultimate" => { horses: 999_999, shares: 999_999 }
  }.freeze

  def set_limits_based_on_plan
    puts "🔥 Chamando set_limits_based_on_plan para usuário #{email} com plano: #{plan}"

    limits = PLAN_LIMITS[self.plan] || PLAN_LIMITS["Basic"]
    self.max_horses = limits[:horses] || 0
    self.max_shares = limits[:shares] || 0

    puts "🎯 Novo max_shares: #{self.max_shares}"
  end



  def adjust_usage_counters
    self.used_horses = [[used_horses || 0, max_horses || 0].min, 0].max
    self.used_shares = [[used_shares || 0, max_shares || 0].min, 0].max
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

  def check_and_downgrade_plan
    if subscription_end.present? && Time.current > subscription_end
      Rails.logger.info("⏳ Assinatura expirada para #{email}. Migrando para o plano Basic.")

      update!(
        plan: "Basic",
        stripe_subscription_id: nil,
        subscription_end: nil
      )

      set_limits_based_on_plan
      adjust_usage_counters
      save!

      Rails.logger.info("✅ #{email} migrado automaticamente para o plano Basic.")
    end
  end

  def self.check_expired_subscriptions
    expired_subscriptions.find_each do |user|
      user.check_and_downgrade_plan
    end
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
