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

    # Featured Tags (user-selected featured hashtags)
    create_table :featured_tags, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.references :tag, foreign_key: true, type: :integer, null: false, index: true
      t.integer :statuses_count, default: 0, null: false
      t.datetime :last_status_at
      
      t.timestamps
    end

    add_index :featured_tags, [:actor_id, :tag_id], unique: true

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

    # Bookmarks
    create_table :bookmarks, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :object_id, null: false, index: true
      
      t.timestamps
    end

    add_index :bookmarks, [:actor_id, :object_id], unique: true
    add_foreign_key :bookmarks, :objects, column: :object_id, primary_key: :id

    # Pinned Statuses
    create_table :pinned_statuses, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :object_id, null: false, index: true
      t.integer :position, default: 0, null: false
      
      t.timestamps
    end

    add_index :pinned_statuses, [:actor_id, :object_id], unique: true
    add_index :pinned_statuses, [:actor_id, :position]
    add_foreign_key :pinned_statuses, :objects, column: :object_id, primary_key: :id

    # Lists (account organization)
    create_table :lists, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :title, null: false
      t.string :replies_policy, default: 'list', null: false # 'list', 'followed', 'none'
      t.boolean :exclusive, default: false, null: false
      
      t.timestamps
    end

    # List Memberships (accounts in lists)
    create_table :list_memberships, id: :integer do |t|
      t.references :list, foreign_key: true, type: :integer, null: false, index: true
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      
      t.timestamps
    end

    add_index :list_memberships, [:list_id, :actor_id], unique: true
  end
end