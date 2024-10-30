class AddDetailsToHorses < ActiveRecord::Migration[7.1]
  def change
    add_column :horses, :height_cm, :integer
    add_column :horses, :gender, :string
    add_column :horses, :color, :string
    add_column :horses, :training_level, :string
    add_column :horses, :piroplasmosis, :boolean
  end
end
