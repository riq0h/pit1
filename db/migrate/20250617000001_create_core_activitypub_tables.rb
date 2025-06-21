# frozen_string_literal: true

class CreateCoreActivitypubTables < ActiveRecord::Migration[8.0]
  def change
    # Core Actors table (users/accounts)
    create_table :actors, id: :integer do |t|
      # Basic user information
      t.string :username, null: false
      t.string :domain, index: true
      t.string :display_name
      t.text :note
      
      # ActivityPub URLs
      t.string :ap_id, null: false, index: { unique: true }
      t.string :inbox_url, null: false
      t.string :outbox_url, null: false
      t.string :followers_url
      t.string :following_url
      t.string :featured_url
      
      # Cryptographic keys
      t.text :public_key
      t.text :private_key
      
      # Actor metadata
      t.boolean :local, default: false, null: false, index: true
      t.boolean :locked, default: false
      t.boolean :bot, default: false
      t.boolean :suspended, default: false
      t.boolean :admin, default: false
      
      # Profile fields
      t.text :fields
      
      # Social counts
      t.integer :followers_count, default: 0
      t.integer :following_count, default: 0
      t.integer :posts_count, default: 0
      
      # ActivityPub compliance
      t.text :raw_data
      t.string :actor_type, default: 'Person'
      t.boolean :discoverable, default: true
      t.boolean :manually_approves_followers, default: false
      
      # Authentication (for local users)
      t.string :password_digest
      
      t.timestamps
    end

    add_index :actors, [:username, :domain], unique: true
    add_index :actors, :username

    # ActivityPub Objects table (posts/content)
    create_table :objects, id: :string do |t|
      # ActivityPub metadata
      t.string :ap_id, null: false, index: { unique: true }
      t.string :object_type, null: false, index: true
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      
      # Content
      t.text :content
      t.text :content_plaintext
      t.text :summary
      t.string :url
      t.string :language
      
      
      # Content metadata
      t.boolean :sensitive, default: false
      t.string :visibility, default: 'public', index: true
      t.text :raw_data
      t.datetime :published_at, index: true
      
      # Local/remote flag
      t.boolean :local, default: false, index: true
      
      # Social counts
      t.integer :replies_count, default: 0
      t.integer :reblogs_count, default: 0
      t.integer :favourites_count, default: 0
      
      # Edit tracking
      t.datetime :edited_at, index: true
      
      t.timestamps
    end

    # ActivityPub Activities table
    create_table :activities, id: :string do |t|
      # ActivityPub metadata
      t.string :ap_id, null: false, index: { unique: true }
      t.string :activity_type, null: false, index: true
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      
      # Activity targets
      t.string :object_ap_id, index: true
      t.string :target_ap_id, index: true
      
      # Content and metadata
      t.text :raw_data
      t.datetime :published_at, index: true
      t.boolean :local, default: false, index: true
      
      # Processing status (for duplicate prevention)
      t.boolean :processed, default: false, index: true
      t.datetime :processed_at
      
      # Delivery tracking
      t.boolean :delivered, default: false
      t.datetime :delivered_at
      t.integer :delivery_attempts, default: 0
      t.text :last_delivery_error
      
      t.timestamps
    end

    # Status Edit History table
    create_table :status_edits, id: :string do |t|
      t.references :object, foreign_key: true, type: :string, null: false, index: true
      
      # Snapshot of content at edit time
      t.text :content
      t.text :content_plaintext
      t.text :summary
      t.boolean :sensitive, default: false
      t.string :language
      
      # Media attachments at edit time
      t.json :media_ids
      t.json :media_descriptions
      
      # Poll data at edit time
      t.json :poll_options
      
      t.datetime :created_at, null: false, index: true
    end

    add_index :status_edits, [:object_id, :created_at]
  end
end
