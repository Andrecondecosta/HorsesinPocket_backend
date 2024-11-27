class CreateJoinTableUsersHorses < ActiveRecord::Migration[7.1]
  def change
    create_join_table :users, :horses do |t|
      t.index :user_id
      t.index :horse_id
      t.foreign_key :users
      t.foreign_key :horses
    end
  end
end
