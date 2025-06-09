class FixRemainingForeignKeyTypes < ActiveRecord::Migration[8.0]
  def up
    # followsテーブルの外部キー修正
    remove_foreign_key :follows, :actors, column: :actor_id if foreign_key_exists?(:follows, :actors, column: :actor_id)
    remove_foreign_key :follows, :actors, column: :target_actor_id if foreign_key_exists?(:follows, :actors, column: :target_actor_id)
    
    change_column :follows, :actor_id, :string
    change_column :follows, :target_actor_id, :string
    
    add_foreign_key :follows, :actors, column: :actor_id
    add_foreign_key :follows, :actors, column: :target_actor_id
    
    # media_attachmentsテーブルの外部キー修正
    remove_foreign_key :media_attachments, :objects if foreign_key_exists?(:media_attachments, :objects)
    remove_foreign_key :media_attachments, :actors if foreign_key_exists?(:media_attachments, :actors)
    
    change_column :media_attachments, :object_id, :string
    change_column :media_attachments, :actor_id, :string
    
    add_foreign_key :media_attachments, :objects, column: :object_id
    add_foreign_key :media_attachments, :actors, column: :actor_id
  end
  
  def down
    # followsテーブルを元に戻す
    remove_foreign_key :follows, :actors, column: :actor_id if foreign_key_exists?(:follows, :actors, column: :actor_id)
    remove_foreign_key :follows, :actors, column: :target_actor_id if foreign_key_exists?(:follows, :actors, column: :target_actor_id)
    
    change_column :follows, :actor_id, :integer
    change_column :follows, :target_actor_id, :integer
    
    add_foreign_key :follows, :actors, column: :actor_id
    add_foreign_key :follows, :actors, column: :target_actor_id
    
    # media_attachmentsテーブルを元に戻す
    remove_foreign_key :media_attachments, :objects if foreign_key_exists?(:media_attachments, :objects)
    remove_foreign_key :media_attachments, :actors if foreign_key_exists?(:media_attachments, :actors)
    
    change_column :media_attachments, :object_id, :integer
    change_column :media_attachments, :actor_id, :integer
    
    add_foreign_key :media_attachments, :objects, column: :object_id
    add_foreign_key :media_attachments, :actors, column: :actor_id
  end
end
