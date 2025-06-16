class ChangeCustomEmojisIdToInteger < ActiveRecord::Migration[8.0]
  def up
    # 既存のcustom_emojisテーブルを削除
    drop_table :custom_emojis if table_exists?(:custom_emojis)
    
    # 整数IDでcustom_emojisテーブルを再作成
    create_table :custom_emojis, id: :integer do |t|
      t.string :shortcode, null: false
      t.string :domain
      t.string :uri
      t.string :image_url
      t.boolean :visible_in_picker, default: true
      t.boolean :disabled, default: false
      t.string :category_id
      t.timestamps
    end
    
    # インデックスを作成
    add_index :custom_emojis, [:shortcode, :domain], unique: true
    add_index :custom_emojis, :shortcode
    
    # 古いActive Storage Attachmentを削除
    execute("DELETE FROM active_storage_attachments WHERE record_type = 'CustomEmoji'")
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert to UUID-based IDs"
  end
end
