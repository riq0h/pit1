class CreateFavourites < ActiveRecord::Migration[8.0]
  def change
    create_table :favourites do |t|
      t.references :actor, null: false, foreign_key: true
      t.references :object, null: false, foreign_key: { to_table: :objects }

      t.timestamps
    end
    
    add_index :favourites, [:actor_id, :object_id], unique: true
  end
end
