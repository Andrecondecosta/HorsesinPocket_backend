class Video < ApplicationRecord
  belongs_to :horse
  has_one_attached :file  # Para armazenar o vídeo no Cloudinary

  validates :file, presence: true
end
