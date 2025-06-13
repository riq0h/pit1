class CreateMutes < ActiveRecord::Migration[8.0]
  def change
    create_table :mutes do |t|
      t.references :actor, null: false, foreign_key: { to_table: :actors }
      t.references :target_actor, null: false, foreign_key: { to_table: :actors }
      t.boolean :notifications, default: true

      t.timestamps
    end
    
    add_index :mutes, [:actor_id, :target_actor_id], unique: true
  end
end
