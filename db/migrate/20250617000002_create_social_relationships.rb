# frozen_string_literal: true

class CreateSocialRelationships < ActiveRecord::Migration[8.0]
  def change
    # Follow relationships
    create_table :follows, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.references :target_actor, foreign_key: { to_table: :actors }, type: :integer, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      t.string :follow_activity_ap_id, index: { unique: true }
      
      # Follow state
      t.boolean :accepted, default: false, index: true
      t.datetime :accepted_at
      
      t.timestamps
    end

    add_index :follows, [:actor_id, :target_actor_id], unique: true

    # Block relationships
    create_table :blocks, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.references :target_actor, foreign_key: { to_table: :actors }, type: :integer, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      
      t.timestamps
    end

    add_index :blocks, [:actor_id, :target_actor_id], unique: true

    # Mute relationships
    create_table :mutes, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.references :target_actor, foreign_key: { to_table: :actors }, type: :integer, null: false, index: true
      
      # ActivityPub metadata
      t.string :ap_id, index: { unique: true }
      
      # Mute options
      t.boolean :notifications, default: true
      
      t.timestamps
    end

    add_index :mutes, [:actor_id, :target_actor_id], unique: true

    # Domain blocks
    create_table :domain_blocks, id: :integer do |t|
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      t.string :domain, null: false
      t.text :reason
      t.boolean :reject_media, default: false
      t.boolean :reject_reports, default: false
      t.boolean :private_comment
      t.text :public_comment
      
      t.timestamps
    end

    add_index :domain_blocks, [:actor_id, :domain], unique: true
  end
end