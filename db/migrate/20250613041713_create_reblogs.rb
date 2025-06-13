class CreateReblogs < ActiveRecord::Migration[8.0]
  def change
    create_table :reblogs do |t|
      t.references :actor, null: false, foreign_key: true, type: :string
      t.string :object_id, null: false

      t.timestamps
    end
    
    add_index :reblogs, [:actor_id, :object_id], unique: true
    add_foreign_key :reblogs, :objects, column: :object_id
  end
end
