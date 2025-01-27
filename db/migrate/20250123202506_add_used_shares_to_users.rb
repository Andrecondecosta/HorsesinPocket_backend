class AddUsedSharesToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :used_shares, :integer, default: 0 # Número de partilhas feitas
  end
end
