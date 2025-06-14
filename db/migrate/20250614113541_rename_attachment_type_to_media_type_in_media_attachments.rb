class RenameAttachmentTypeToMediaTypeInMediaAttachments < ActiveRecord::Migration[8.0]
  def change
    rename_column :media_attachments, :attachment_type, :media_type
    
    # インデックスも更新
    if index_exists?(:media_attachments, :attachment_type)
      remove_index :media_attachments, :attachment_type
    end
    
    unless index_exists?(:media_attachments, :media_type)
      add_index :media_attachments, :media_type
    end
  end
end
