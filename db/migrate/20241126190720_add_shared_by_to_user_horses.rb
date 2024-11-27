class AddSharedByToUserHorses < ActiveRecord::Migration[7.1]
  def change
    add_column :user_horses, :shared_by, :integer
    add_foreign_key :user_horses, :users, column: :shared_by # Relaciona o shared_by com o ID de users
  end
end
