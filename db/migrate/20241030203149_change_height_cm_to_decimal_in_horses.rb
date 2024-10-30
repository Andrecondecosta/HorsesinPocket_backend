class ChangeHeightCmToDecimalInHorses < ActiveRecord::Migration[7.1]
  def change
    change_column :horses, :height_cm, :decimal, precision: 4, scale: 2
  end
end
