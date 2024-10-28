class Xray < ApplicationRecord
  belongs_to :horse
  has_one_attached :image  # Para armazenar a imagem de raio-X no Cloudinary

  validates :image, presence: true
end
