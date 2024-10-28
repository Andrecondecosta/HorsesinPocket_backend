class Photo < ApplicationRecord
  belongs_to :horse
  has_one_attached :file

  validates :image, presence: true
end
