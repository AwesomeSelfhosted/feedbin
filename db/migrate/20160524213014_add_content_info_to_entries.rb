class AddContentInfoToEntries < ActiveRecord::Migration
  def up
    add_column :entries, :content_info, :text, array: true
    change_column_default(:entries, :content_info, [])
  end

  def down
    remove_column :entries, :content_info
  end
end
