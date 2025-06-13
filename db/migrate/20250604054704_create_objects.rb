class CreateObjects < ActiveRecord::Migration[8.0]
  def change
    create_table :objects, id: :string do |t|
      # ActivityPub情報
      t.string :ap_id, null: false
      t.string :object_type, null: false, default: 'Note'
      t.references :actor, null: false, foreign_key: true

      # コンテンツ（HTMLとプレーンテキストの両方を保持）
      t.text :content                    # HTML版
      t.text :content_plaintext          # プレーン版（FTS5検索用）

      t.text :summary                    # Content Warning
      t.string :url
      t.string :language, default: 'ja'

      # 返信・会話
      t.string :in_reply_to_ap_id
      t.string :conversation_ap_id

      # メディア情報
      t.string :media_type
      t.string :blurhash
      t.integer :width
      t.integer :height

      # 設定
      t.boolean :sensitive, default: false
      t.string :visibility, default: 'public'

      # ActivityPub データ
      t.json :raw_data
      t.datetime :published_at

      # メタデータ
      t.boolean :local, default: false
      t.integer :replies_count, default: 0
      t.integer :reblogs_count, default: 0
      t.integer :favourites_count, default: 0

      t.timestamps
    end

    # 基本インデックス
    add_index :objects, :ap_id, unique: true unless index_exists?(:objects, :ap_id)
    add_index :objects, :object_type unless index_exists?(:objects, :object_type)
    add_index :objects, :published_at unless index_exists?(:objects, :published_at)
    add_index :objects, :visibility unless index_exists?(:objects, :visibility)
    add_index :objects, :local unless index_exists?(:objects, :local)
    add_index :objects, :in_reply_to_ap_id unless index_exists?(:objects, :in_reply_to_ap_id)
    add_index :objects, :conversation_ap_id unless index_exists?(:objects, :conversation_ap_id)

    # FTS5仮想テーブルは別のマイグレーションで作成
  end
end
