class AddLimitsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :max_horses, :integer, null: true
    add_column :users, :max_shares, :integer, null: true
  end
end
