class Video < ApplicationRecord
  belongs_to :horse
  has_one_attached :video  # Para armazenar o vídeo no Cloudinary

  validates :video, presence: true
end
