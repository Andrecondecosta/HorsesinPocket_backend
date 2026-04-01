class DeviceToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :platform, inclusion: { in: %w[ios android] }

  scope :active, -> { where(active: true) }

  def touch_last_used
    update_column(:last_used_at, Time.current)
  end
end
