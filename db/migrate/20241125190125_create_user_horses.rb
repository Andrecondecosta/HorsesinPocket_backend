class CreateUserHorses < ActiveRecord::Migration[7.1]
  def change
    create_table :user_horses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :horse, null: false, foreign_key: true

      t.timestamps
    end
  end
end
