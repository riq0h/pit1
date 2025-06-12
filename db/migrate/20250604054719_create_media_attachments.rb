class CreateMediaAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :media_attachments do |t|
      # 関連情報
      t.references :object, type: :string, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: true

      # ファイル情報
      t.string :file_name
      t.string :content_type
      t.bigint :file_size
      t.string :storage_path
      t.string :remote_url

      # 画像情報
      t.integer :width
      t.integer :height
      t.string :blurhash
      t.text :description

      # メタデータ
      t.string :attachment_type, default: 'image'
      t.boolean :processed, default: false
      t.json :metadata

      t.timestamps
    end

    # インデックス設定
    add_index :media_attachments, :attachment_type unless index_exists?(:media_attachments, :attachment_type)
    add_index :media_attachments, :processed unless index_exists?(:media_attachments, :processed)
    add_index :media_attachments, :blurhash unless index_exists?(:media_attachments, :blurhash)
  end
end
