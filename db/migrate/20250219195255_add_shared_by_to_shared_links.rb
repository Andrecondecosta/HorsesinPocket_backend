class AddSharedByToSharedLinks < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:shared_links, :shared_by)
      add_column :shared_links, :shared_by, :integer
    end
  end
end
