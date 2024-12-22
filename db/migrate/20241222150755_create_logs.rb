class CreateLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :logs do |t|
      t.string :action
      t.string :horse_name
      t.string :recipient
      t.integer :user_id

      t.timestamps
    end
  end
end
