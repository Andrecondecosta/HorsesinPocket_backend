class AddBreedAndBreederToHorses < ActiveRecord::Migration[7.1]
  def change
    add_column :horses, :breed, :string
    add_column :horses, :breeder, :string
  end
end
