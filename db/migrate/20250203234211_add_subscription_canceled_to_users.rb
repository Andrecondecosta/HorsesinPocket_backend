class AddSubscriptionCanceledToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subscription_canceled, :boolean, default: false, null: false
  end
end
