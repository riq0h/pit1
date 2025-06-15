class CreateConversationParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_participants do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :conversation_participants, [:conversation_id, :actor_id], unique: true, name: 'index_conversation_participants_unique'
  end
end
