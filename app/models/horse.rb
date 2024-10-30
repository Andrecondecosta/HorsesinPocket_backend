class Horse < ApplicationRecord
  belongs_to :user
  has_many_attached :images

  validates :name, :age, :height_cm, :gender, :color, presence: true
  validates :gender, inclusion: { in: ['gelding', 'mare', 'stallion'], message: "%{value} is not a valid gender" }
  validates :training_level, length: { maximum: 100 }
  validates :color, length: { maximum: 20 } # Ajuste do comprimento de cor para aceitar mais valores
end
