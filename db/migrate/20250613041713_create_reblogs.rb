class CreateReblogs < ActiveRecord::Migration[8.0]
  def change
    create_table :reblogs do |t|
      t.references :actor, null: false, foreign_key: true
      t.references :object, null: false, foreign_key: { to_table: :objects }

      t.timestamps
    end
    
    add_index :reblogs, [:actor_id, :object_id], unique: true
  end
end
