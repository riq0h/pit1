class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.integer :last_status_id
      t.boolean :unread, default: false, null: false

      t.timestamps
    end
    
    add_index :conversations, :last_status_id
    add_index :conversations, :unread
  end
end
