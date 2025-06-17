# frozen_string_literal: true

class CreateContentInteractions < ActiveRecord::Migration[8.0]
  def change
    # Favourites (likes)
    create_table :favourites, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :object_id, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      
      t.timestamps
    end

    add_index :favourites, [:actor_id, :object_id], unique: true
    add_foreign_key :favourites, :objects, column: :object_id, primary_key: :id

    # Reblogs (shares/boosts)
    create_table :reblogs, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :object_id, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      t.string :visibility, default: 'public'
      
      t.timestamps
    end

    add_index :reblogs, [:actor_id, :object_id], unique: true
    add_foreign_key :reblogs, :objects, column: :object_id, primary_key: :id

    # Tags (hashtags)
    create_table :tags, id: :integer do |t|
      t.string :name, null: false, index: { unique: true }
      t.integer :usage_count, default: 0
      t.boolean :trending, default: false
      
      t.timestamps
    end

    # Object-Tag relationships
    create_table :object_tags, id: :integer do |t|
      t.string :object_id, null: false, index: true
      t.references :tag, foreign_key: true, type: :integer, null: false, index: true
      
      t.timestamps
    end

    add_index :object_tags, [:object_id, :tag_id], unique: true
    add_foreign_key :object_tags, :objects, column: :object_id, primary_key: :id

    # Mentions
    create_table :mentions, id: :integer do |t|
      t.string :object_id, null: false, index: true
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      
      t.timestamps
    end

    add_index :mentions, [:object_id, :actor_id], unique: true
    add_foreign_key :mentions, :objects, column: :object_id, primary_key: :id
  end
end