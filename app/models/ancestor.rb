class Ancestor < ApplicationRecord
  belongs_to :horse

  validates :relation_type, presence: true
  validates :name, presence: true
end
