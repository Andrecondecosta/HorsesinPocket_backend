class Ancestor < ApplicationRecord
  belongs_to :horse

  validates :relation_type, presence: true
  validates :name, presence: true
  validates :relation_type, uniqueness: { scope: :horse_id, message: "Já existe um ancestral com este tipo de relação." }
end
