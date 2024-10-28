class CreateVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :videos do |t|
      t.references :horse, null: false, foreign_key: true

      t.timestamps
    end
  end
end
