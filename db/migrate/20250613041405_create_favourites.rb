class CreateFavourites < ActiveRecord::Migration[8.0]
  def change
    create_table :favourites do |t|
      t.references :actor, null: false, foreign_key: true, type: :string
      t.string :object_id, null: false

      t.timestamps
    end
    
    add_index :favourites, [:actor_id, :object_id], unique: true
    add_foreign_key :favourites, :objects, column: :object_id
  end
end
