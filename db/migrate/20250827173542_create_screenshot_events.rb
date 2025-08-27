class CreateScreenshotEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :screenshot_events do |t|
      t.references :horse, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
