class Horse < ApplicationRecord
  belongs_to :creator, class_name: 'User', foreign_key: :user_id
  has_many :user_horses, dependent: :destroy
  has_many :users, through: :user_horses

  has_many_attached :images
  has_many_attached :videos
  has_many :ancestors, dependent: :destroy

  accepts_nested_attributes_for :ancestors, allow_destroy: true

  validates :name, :age, :height_cm, :gender, :color, presence: true
  validates :gender, inclusion: { in: ['gelding', 'mare', 'stallion'], message: "%{value} is not a valid gender" }
  validates :training_level, length: { maximum: 100 }
  validates :color, length: { maximum: 20 } # Ajuste do comprimento de cor para aceitar mais valores
  # Métodos auxiliares para acessar ancestrais específicos

  before_update :prevent_creator_change, if: :user_id_changed?



  def father
    ancestors.find_by(relation_type: 'father')
  end

  def mother
    ancestors.find_by(relation_type: 'mother')
  end

  def paternal_grandfather
    ancestors.find_by(relation_type: 'paternal_grandfather')
  end

  def paternal_grandmother
    ancestors.find_by(relation_type: 'paternal_grandmother')
  end

  def maternal_grandfather
    ancestors.find_by(relation_type: 'maternal_grandfather')
  end

  def maternal_grandmother
    ancestors.find_by(relation_type: 'maternal_grandmother')
  end
end

private

def prevent_creator_change
  errors.add(:user_id, "não pode ser alterado")
  throw(:abort)
end
