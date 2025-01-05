class CreateSharedLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :shared_links do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :horse, null: false, foreign_key: true
      t.datetime :expires_at
      t.string :status, default: 'active'

      t.timestamps
    end
  end
end
