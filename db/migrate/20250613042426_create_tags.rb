class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.integer :usages_count, default: 0, null: false
      t.datetime :last_used_at
      t.boolean :trending, default: false

      t.timestamps
    end
    
    add_index :tags, :name, unique: true
    add_index :tags, :usages_count
    add_index :tags, :trending
    add_index :tags, :last_used_at
  end
end
