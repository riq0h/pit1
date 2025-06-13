class CreateObjectTags < ActiveRecord::Migration[8.0]
  def change
    create_table :object_tags do |t|
      t.string :object_id, null: false
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :object_tags, [:object_id, :tag_id], unique: true
    add_foreign_key :object_tags, :objects, column: :object_id
  end
end
