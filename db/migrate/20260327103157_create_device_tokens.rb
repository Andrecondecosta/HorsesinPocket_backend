class CreateDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :device_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :token, null: false
      t.string :platform, default: 'ios'
      t.boolean :active, default: true
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :device_tokens, :token, unique: true
  end
end
