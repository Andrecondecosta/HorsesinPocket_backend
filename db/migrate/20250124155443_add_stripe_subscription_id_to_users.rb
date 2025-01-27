class AddStripeSubscriptionIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :stripe_subscription_id, :string
    add_index :users, :stripe_subscription_id, unique: true # Torna único para evitar duplicações
  end
end
