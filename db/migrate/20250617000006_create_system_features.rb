# frozen_string_literal: true

class CreateSystemFeatures < ActiveRecord::Migration[8.0]
  def change
    # User limits and quotas
    create_table :user_limits, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: { unique: true }
      
      # Limit types and values
      t.string :limit_type, null: false
      t.integer :limit_value, null: false
      t.integer :current_usage, default: 0
      t.datetime :reset_at
      
      t.timestamps
    end

    add_index :user_limits, [:actor_id, :limit_type], unique: true

    # Content filters
    create_table :filters, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :title, null: false
      t.text :context, null: false # JSON array: ['home', 'notifications', 'public', 'thread', 'account']
      t.datetime :expires_at
      t.string :filter_action, default: 'warn', null: false # 'warn' or 'hide'
      
      t.timestamps
    end

    # Filter keywords
    create_table :filter_keywords, id: :integer do |t|
      t.references :filter, foreign_key: true, type: :integer, null: false, index: true
      t.string :keyword, null: false
      t.boolean :whole_word, default: false, null: false
      
      t.timestamps
    end

    # Filter statuses (specific status filtering)
    create_table :filter_statuses, id: :integer do |t|
      t.references :filter, foreign_key: true, type: :integer, null: false, index: true
      t.string :status_id, null: false, index: true
      
      t.timestamps
    end

    add_index :filter_keywords, [:filter_id, :keyword], unique: true
    add_index :filter_statuses, [:filter_id, :status_id], unique: true
    add_foreign_key :filter_statuses, :objects, column: :status_id, primary_key: :id

    # Push notification subscriptions
    create_table :web_push_subscriptions, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :endpoint, null: false
      t.string :p256dh_key, null: false
      t.string :auth_key, null: false
      t.text :data # JSON for alert types and other settings
      
      t.timestamps
    end

    add_index :web_push_subscriptions, [:actor_id, :endpoint], unique: true
  end
end