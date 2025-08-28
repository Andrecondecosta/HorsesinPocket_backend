class AddStatusToScreenshotEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :screenshot_events, :status, :string,  default: "pending"
  end
end
