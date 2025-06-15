class AddAdminToActors < ActiveRecord::Migration[8.0]
  def change
    add_column :actors, :admin, :boolean, default: false, null: false
    add_index :actors, :admin
  end
end
