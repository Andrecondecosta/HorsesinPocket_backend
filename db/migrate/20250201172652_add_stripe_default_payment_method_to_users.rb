class AddStripeDefaultPaymentMethodToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :stripe_default_payment_method, :string
    add_index :users, :stripe_default_payment_method, unique: true
  end
end
