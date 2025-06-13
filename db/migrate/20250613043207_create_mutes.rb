class CreateMutes < ActiveRecord::Migration[8.0]
  def change
    create_table :mutes do |t|
      t.string :actor_id, null: false
      t.string :target_actor_id, null: false
      t.boolean :notifications, default: true

      t.timestamps
    end
    
    add_index :mutes, [:actor_id, :target_actor_id], unique: true
    add_foreign_key :mutes, :actors, column: :actor_id
    add_foreign_key :mutes, :actors, column: :target_actor_id
  end
end
