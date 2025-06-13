class CreateObjectTags < ActiveRecord::Migration[8.0]
  def change
    create_table :object_tags do |t|
      t.references :object, null: false, foreign_key: { to_table: :objects }
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :object_tags, [:object_id, :tag_id], unique: true
  end
end
