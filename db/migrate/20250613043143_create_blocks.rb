class CreateBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :blocks do |t|
      t.references :actor, null: false, foreign_key: { to_table: :actors }
      t.references :target_actor, null: false, foreign_key: { to_table: :actors }

      t.timestamps
    end
    
    add_index :blocks, [:actor_id, :target_actor_id], unique: true
  end
end
