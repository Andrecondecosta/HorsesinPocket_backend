class User < ApplicationRecord
  has_many :horses, dependent: :destroy
  has_many :user_horses, dependent: :destroy
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :validatable

  def name
    "#{first_name} #{last_name}"
  end

  # Adiciona um booleano `admin` na tabela Users para diferenciar administradores
  def admin?
    self.admin
  end
end
