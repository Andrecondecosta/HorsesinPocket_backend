class RenameAddressToCountryInUsers < ActiveRecord::Migration[7.0]
  def change
    rename_column :users, :address, :country
  end
end
