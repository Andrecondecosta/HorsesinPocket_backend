class CreateHorses < ActiveRecord::Migration[7.1]
  def change
    create_table :horses do |t|
      t.string :name
      t.integer :age
      t.text :description
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
