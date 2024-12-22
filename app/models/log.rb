class Log < ApplicationRecord
  belongs_to :user, optional: true # Caso o `user_id` possa ser nulo
end
