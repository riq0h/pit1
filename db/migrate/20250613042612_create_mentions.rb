class CreateMentions < ActiveRecord::Migration[8.0]
  def change
    create_table :mentions do |t|
      t.string :object_id, null: false
      t.references :actor, null: false, foreign_key: true, type: :string
      t.string :acct # @username@domain format

      t.timestamps
    end
    
    add_index :mentions, [:object_id, :actor_id], unique: true
    add_foreign_key :mentions, :objects, column: :object_id
  end
end
