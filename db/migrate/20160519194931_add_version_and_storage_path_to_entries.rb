class AddVersionAndStoragePathToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :version, :int
    add_column :entries, :storage_path, :text
  end
end
