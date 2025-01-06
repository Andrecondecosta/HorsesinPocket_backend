class AddUsedAtToSharedLinks < ActiveRecord::Migration[7.1]
  def change
    add_column :shared_links, :used_at, :datetime
  end
end
