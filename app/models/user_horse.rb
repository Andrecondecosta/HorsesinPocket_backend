class UserHorse < ApplicationRecord
  enum status: { active: "active", pending_approval: "pending_approval", revoked: "revoked" }


  belongs_to :user
  belongs_to :horse

  belongs_to :sharer, class_name: 'User', foreign_key: 'shared_by', optional: true

end
