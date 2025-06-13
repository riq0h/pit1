class CreateMentions < ActiveRecord::Migration[8.0]
  def change
    create_table :mentions do |t|
      t.references :object, null: false, foreign_key: { to_table: :objects }
      t.references :actor, null: false, foreign_key: true
      t.string :acct # @username@domain format

      t.timestamps
    end
    
    add_index :mentions, [:object_id, :actor_id], unique: true
  end
end
