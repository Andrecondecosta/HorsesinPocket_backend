class Horse < ApplicationRecord
  belongs_to :user
  has_many_attached :images  # Atualizar para has_many_attached
  has_many :photos, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :xrays, dependent: :destroy

  validates :name, presence: true
  validates :age, numericality: { only_integer: true, greater_than: 0 }
end
