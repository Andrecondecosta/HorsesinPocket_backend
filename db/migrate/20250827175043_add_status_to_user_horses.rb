class AddStatusToUserHorses < ActiveRecord::Migration[7.1]
  def change
    add_column :user_horses, :status, :string, default: 'active'
  end
end
