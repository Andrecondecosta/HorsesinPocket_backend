class CreateAncestors < ActiveRecord::Migration[7.1]
  def change
    create_table :ancestors do |t|
      t.references :horse, null: false, foreign_key: true
      t.string :name
      t.string :breed
      t.string :breeder
      t.string :relation_type

      t.timestamps
    end
    add_index :ancestors, [:horse_id, :relation_type], unique: true
  end
end
