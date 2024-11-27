class UserHorse < ApplicationRecord
  belongs_to :user
  belongs_to :horse

  belongs_to :sharer, class_name: 'User', foreign_key: 'shared_by', optional: true
end
