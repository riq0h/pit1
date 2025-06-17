# frozen_string_literal: true

class CreateMessagingSystem < ActiveRecord::Migration[8.0]
  def change
    # Conversations (direct message threads)
    create_table :conversations, id: :integer do |t|
      t.string :ap_id, index: { unique: true }
      t.string :subject
      t.boolean :local, default: true
      t.boolean :unread, default: false
      t.datetime :last_message_at, index: true
      t.string :last_status_id
      
      t.timestamps
    end

    # Conversation participants
    create_table :conversation_participants, id: :integer do |t|
      t.references :conversation, foreign_key: true, type: :integer, null: false, index: true
      t.references :actor, foreign_key: true, type: :integer, null: false, index: true
      
      # Participant status
      t.boolean :active, default: true
      t.datetime :last_read_at
      
      t.timestamps
    end

    add_index :conversation_participants, [:conversation_id, :actor_id], unique: true

    # Threading and conversations support for objects
    add_column :objects, :in_reply_to_ap_id, :string
    add_column :objects, :conversation_ap_id, :string
    add_column :objects, :conversation_id, :integer, null: true

    add_index :objects, :in_reply_to_ap_id
    add_index :objects, :conversation_ap_id
    add_index :objects, :conversation_id
    add_foreign_key :objects, :conversations
  end
end