class CreateBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :blocks do |t|
      t.string :actor_id, null: false
      t.string :target_actor_id, null: false

      t.timestamps
    end
    
    add_index :blocks, [:actor_id, :target_actor_id], unique: true
    add_foreign_key :blocks, :actors, column: :actor_id
    add_foreign_key :blocks, :actors, column: :target_actor_id
  end
end
