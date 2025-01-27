class CreatePlans < ActiveRecord::Migration[7.0]
  def change
    create_table :plans do |t|
      t.string :name
      t.decimal :price
      t.integer :max_horses
      t.integer :max_transfers

      t.timestamps
    end
  end
end
